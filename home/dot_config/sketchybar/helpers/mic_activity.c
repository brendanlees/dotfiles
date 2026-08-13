#include <CoreAudio/CoreAudio.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <spawn.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;

static AudioObjectID *watched_processes = NULL;
static size_t watched_process_count = 0;
static AudioObjectID *watched_devices = NULL;
static size_t watched_device_count = 0;
static pthread_mutex_t refresh_mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t refresh_condition = PTHREAD_COND_INITIALIZER;
static bool refresh_requested = false;
static bool process_list_changed = false;
static bool device_list_changed = false;

static bool read_u32(AudioObjectID object, AudioObjectPropertySelector selector,
                     AudioObjectPropertyScope scope, UInt32 *value) {
  AudioObjectPropertyAddress address = {
      selector,
      scope,
      kAudioObjectPropertyElementMain,
  };
  UInt32 size = sizeof(*value);

  return AudioObjectHasProperty(object, &address) &&
         AudioObjectGetPropertyData(object, &address, 0, NULL, &size, value) ==
             noErr;
}

static bool read_object_list(AudioObjectID object,
                             AudioObjectPropertySelector selector,
                             AudioObjectID **objects, size_t *count) {
  AudioObjectPropertyAddress address = {
      selector,
      kAudioObjectPropertyScopeGlobal,
      kAudioObjectPropertyElementMain,
  };
  UInt32 size = 0;
  *objects = NULL;
  *count = 0;

  if (!AudioObjectHasProperty(object, &address) ||
      AudioObjectGetPropertyDataSize(object, &address, 0, NULL, &size) !=
          noErr) {
    return false;
  }
  if (size == 0) {
    return true;
  }

  AudioObjectID *result = malloc(size);
  if (result == NULL) {
    return false;
  }
  if (AudioObjectGetPropertyData(object, &address, 0, NULL, &size, result) !=
      noErr) {
    free(result);
    return false;
  }

  *objects = result;
  *count = size / sizeof(*result);
  return true;
}

static bool process_has_input_device(AudioObjectID process);

/* macOS 14+ exposes the processes that currently have an input stream. */
static bool process_input_state(bool *active) {
  AudioObjectID *processes = NULL;
  size_t count = 0;
  *active = false;

  if (!read_object_list(kAudioObjectSystemObject,
                        kAudioHardwarePropertyProcessObjectList, &processes,
                        &count)) {
    return false;
  }
  if (count == 0) {
    return true;
  }

  bool read_any = false;
  for (size_t i = 0; i < count; i++) {
    UInt32 running = 0;
    if (read_u32(processes[i], kAudioProcessPropertyIsRunningInput,
                 kAudioObjectPropertyScopeGlobal, &running)) {
      read_any = true;
      if (running != 0 && process_has_input_device(processes[i])) {
        *active = true;
        break;
      }
    }
  }

  free(processes);
  return read_any;
}

static bool process_has_input_device(AudioObjectID process) {
  AudioObjectPropertyAddress address = {
      kAudioProcessPropertyDevices,
      kAudioObjectPropertyScopeInput,
      kAudioObjectPropertyElementMain,
  };
  UInt32 size = 0;

  return AudioObjectHasProperty(process, &address) &&
         AudioObjectGetPropertyDataSize(process, &address, 0, NULL, &size) ==
             noErr &&
         size >= sizeof(AudioObjectID);
}

static bool device_has_input(AudioObjectID device) {
  AudioObjectPropertyAddress address = {
      kAudioDevicePropertyStreamConfiguration,
      kAudioDevicePropertyScopeInput,
      kAudioObjectPropertyElementMain,
  };
  UInt32 size = 0;

  if (AudioObjectGetPropertyDataSize(device, &address, 0, NULL, &size) !=
          noErr ||
      size == 0) {
    return false;
  }

  AudioBufferList *buffers = malloc(size);
  if (buffers == NULL) {
    return false;
  }

  bool has_input = false;
  if (AudioObjectGetPropertyData(device, &address, 0, NULL, &size, buffers) ==
      noErr) {
    for (UInt32 i = 0; i < buffers->mNumberBuffers; i++) {
      if (buffers->mBuffers[i].mNumberChannels > 0) {
        has_input = true;
        break;
      }
    }
  }

  free(buffers);
  return has_input;
}

static bool device_is_virtual(AudioObjectID device) {
  UInt32 transport = 0;
  return read_u32(device, kAudioDevicePropertyTransportType,
                  kAudioObjectPropertyScopeGlobal, &transport) &&
         transport == kAudioDeviceTransportTypeVirtual;
}

/* Fallback for capture routed through a helper such as SoundSource. */
static bool any_device_uses_input(void) {
  AudioObjectID *devices = NULL;
  size_t count = 0;

  if (!read_object_list(kAudioObjectSystemObject, kAudioHardwarePropertyDevices,
                        &devices, &count)) {
    return false;
  }

  bool active = false;
  for (size_t i = 0; i < count; i++) {
    UInt32 running = 0;
    if (device_has_input(devices[i]) && !device_is_virtual(devices[i]) &&
        read_u32(devices[i], kAudioDevicePropertyDeviceIsRunningSomewhere,
                 kAudioDevicePropertyScopeInput, &running) &&
        running != 0) {
      active = true;
      break;
    }
  }

  free(devices);
  return active;
}

/* A powered USB mic is live even before an application opens its stream. */
static bool any_live_usb_input(void) {
  AudioObjectID *devices = NULL;
  size_t count = 0;

  if (!read_object_list(kAudioObjectSystemObject, kAudioHardwarePropertyDevices,
                        &devices, &count)) {
    return false;
  }

  bool live = false;
  for (size_t i = 0; i < count; i++) {
    UInt32 transport = 0;
    UInt32 alive = 1;
    if (!device_has_input(devices[i]) ||
        !read_u32(devices[i], kAudioDevicePropertyTransportType,
                  kAudioObjectPropertyScopeGlobal, &transport) ||
        transport != kAudioDeviceTransportTypeUSB) {
      continue;
    }

    if (!read_u32(devices[i], kAudioDevicePropertyDeviceIsAlive,
                  kAudioObjectPropertyScopeGlobal, &alive) || alive != 0) {
      live = true;
      break;
    }
  }

  free(devices);
  return live;
}

static bool microphone_is_active(void) {
  bool process_active = false;
  process_input_state(&process_active);
  return process_active || any_device_uses_input() || any_live_usb_input();
}

static OSStatus property_changed(AudioObjectID object, UInt32 address_count,
                                 const AudioObjectPropertyAddress *addresses,
                                 void *context) {
  (void)context;

  pthread_mutex_lock(&refresh_mutex);
  refresh_requested = true;
  if (object == kAudioObjectSystemObject) {
    for (UInt32 i = 0; i < address_count; i++) {
      if (addresses[i].mSelector ==
          kAudioHardwarePropertyProcessObjectList) {
        process_list_changed = true;
      } else if (addresses[i].mSelector == kAudioHardwarePropertyDevices) {
        device_list_changed = true;
      }
    }
  }
  pthread_cond_signal(&refresh_condition);
  pthread_mutex_unlock(&refresh_mutex);
  return noErr;
}

static void replace_process_listeners(void) {
  AudioObjectPropertyAddress running_address = {
      kAudioProcessPropertyIsRunningInput,
      kAudioObjectPropertyScopeGlobal,
      kAudioObjectPropertyElementMain,
  };
  AudioObjectPropertyAddress devices_address = {
      kAudioProcessPropertyDevices,
      kAudioObjectPropertyScopeInput,
      kAudioObjectPropertyElementMain,
  };

  for (size_t i = 0; i < watched_process_count; i++) {
    AudioObjectRemovePropertyListener(watched_processes[i], &running_address,
                                      property_changed, NULL);
    AudioObjectRemovePropertyListener(watched_processes[i], &devices_address,
                                      property_changed, NULL);
  }
  free(watched_processes);
  watched_processes = NULL;
  watched_process_count = 0;

  AudioObjectID *processes = NULL;
  size_t count = 0;
  if (!read_object_list(kAudioObjectSystemObject,
                        kAudioHardwarePropertyProcessObjectList, &processes,
                        &count)) {
    return;
  }

  for (size_t i = 0; i < count; i++) {
    if (AudioObjectHasProperty(processes[i], &running_address)) {
      AudioObjectAddPropertyListener(processes[i], &running_address,
                                     property_changed, NULL);
    }
    if (AudioObjectHasProperty(processes[i], &devices_address)) {
      AudioObjectAddPropertyListener(processes[i], &devices_address,
                                     property_changed, NULL);
    }
  }
  watched_processes = processes;
  watched_process_count = count;
}

static void replace_device_listeners(void) {
  AudioObjectPropertyAddress running_address = {
      kAudioDevicePropertyDeviceIsRunningSomewhere,
      kAudioDevicePropertyScopeInput,
      kAudioObjectPropertyElementMain,
  };
  AudioObjectPropertyAddress alive_address = {
      kAudioDevicePropertyDeviceIsAlive,
      kAudioObjectPropertyScopeGlobal,
      kAudioObjectPropertyElementMain,
  };

  for (size_t i = 0; i < watched_device_count; i++) {
    AudioObjectRemovePropertyListener(watched_devices[i], &running_address,
                                      property_changed, NULL);
    AudioObjectRemovePropertyListener(watched_devices[i], &alive_address,
                                      property_changed, NULL);
  }
  free(watched_devices);
  watched_devices = NULL;
  watched_device_count = 0;

  AudioObjectID *devices = NULL;
  size_t count = 0;
  if (!read_object_list(kAudioObjectSystemObject, kAudioHardwarePropertyDevices,
                        &devices, &count)) {
    return;
  }

  for (size_t i = 0; i < count; i++) {
    if (!device_has_input(devices[i])) {
      continue;
    }
    if (AudioObjectHasProperty(devices[i], &running_address)) {
      AudioObjectAddPropertyListener(devices[i], &running_address,
                                     property_changed, NULL);
    }
    if (AudioObjectHasProperty(devices[i], &alive_address)) {
      AudioObjectAddPropertyListener(devices[i], &alive_address,
                                     property_changed, NULL);
    }
  }
  watched_devices = devices;
  watched_device_count = count;
}

static void publish_state(const char *sketchybar, bool active) {
  char state_argument[32];
  snprintf(state_argument, sizeof(state_argument), "MIC_ACTIVE=%d",
           active ? 1 : 0);

  char *const arguments[] = {
      (char *)sketchybar,
      "--trigger",
      "microphone_change",
      state_argument,
      NULL,
  };
  pid_t child = 0;
  if (posix_spawn(&child, sketchybar, NULL, NULL, arguments, environ) == 0) {
    while (waitpid(child, NULL, 0) == -1 && errno == EINTR) {
    }
  }
}

static int acquire_watcher_lock(const char *lock_path) {
  int lock_fd = open(lock_path, O_CREAT | O_RDWR, 0600);
  if (lock_fd == -1 || flock(lock_fd, LOCK_EX | LOCK_NB) == -1) {
    if (lock_fd != -1) {
      close(lock_fd);
    }
    return -1;
  }

  if (ftruncate(lock_fd, 0) == 0) {
    dprintf(lock_fd, "%ld\n", (long)getpid());
    fsync(lock_fd);
  }
  return lock_fd;
}

static int watch_microphone(const char *lock_path, const char *sketchybar) {
  int lock_fd = acquire_watcher_lock(lock_path);
  if (lock_fd == -1) {
    return 0;
  }

  AudioObjectPropertyAddress process_list_address = {
      kAudioHardwarePropertyProcessObjectList,
      kAudioObjectPropertyScopeGlobal,
      kAudioObjectPropertyElementMain,
  };
  AudioObjectPropertyAddress device_list_address = {
      kAudioHardwarePropertyDevices,
      kAudioObjectPropertyScopeGlobal,
      kAudioObjectPropertyElementMain,
  };

  if (AudioObjectHasProperty(kAudioObjectSystemObject, &process_list_address)) {
    AudioObjectAddPropertyListener(kAudioObjectSystemObject,
                                   &process_list_address, property_changed,
                                   NULL);
  }
  AudioObjectAddPropertyListener(kAudioObjectSystemObject, &device_list_address,
                                 property_changed, NULL);

  bool last_active = microphone_is_active();
  replace_process_listeners();
  replace_device_listeners();
  publish_state(sketchybar, last_active);

  for (;;) {
    pthread_mutex_lock(&refresh_mutex);
    while (!refresh_requested) {
      pthread_cond_wait(&refresh_condition, &refresh_mutex);
    }
    refresh_requested = false;
    bool rebuild_processes = process_list_changed;
    bool rebuild_devices = device_list_changed;
    process_list_changed = false;
    device_list_changed = false;
    pthread_mutex_unlock(&refresh_mutex);

    if (rebuild_processes) {
      replace_process_listeners();
    }
    if (rebuild_devices) {
      replace_device_listeners();
    }
    bool active = microphone_is_active();
    if (active != last_active) {
      publish_state(sketchybar, active);
      last_active = active;
    }
  }

  close(lock_fd);
  return 0;
}

int main(int argc, char **argv) {
  if (argc == 4 && strcmp(argv[1], "--watch") == 0) {
    return watch_microphone(argv[2], argv[3]);
  }
  if (argc != 1) {
    fprintf(stderr, "usage: %s [--watch LOCK_PATH SKETCHYBAR_PATH]\n", argv[0]);
    return 2;
  }

  puts(microphone_is_active() ? "active" : "inactive");
  return 0;
}

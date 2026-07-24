---
name: shield-health-check
description: Use when checking, troubleshooting, or improving NVIDIA Shield / Android TV performance over ADB or SMB, especially slow UI, high memory pressure, CPU spikes, thermal concerns, reboot comparisons, or ADB authorization issues.
---

# Shield Health Check

## Overview

Diagnose NVIDIA Shield performance with evidence before changes. Start read-only, identify the bottleneck, ask before any reboot or tweak, then collect an after-snapshot to prove whether the action helped.

Core principle: **no performance tweaks without a baseline and a comparison point.**

## When to Use

Use this when the user asks to:

- Check or improve NVIDIA Shield / Android TV speed or responsiveness.
- Connect to a Shield over ADB or SMB for diagnostics.
- Investigate slow UI, launcher lag, playback sluggishness, high CPU, RAM pressure, storage pressure, or thermal throttling.
- Compare health before and after rebooting or changing Shield settings.
- Troubleshoot ADB states such as `unauthorized`, missing prompts, or reconnect failures.

Do not use this for unrelated Android development, app debugging, or irreversible device modification unless the user explicitly scopes the task that way.

## Safety Rules

1. **Read-only first.** Baseline diagnostics must not change Shield state.
2. **Ask before every state change.** Rebooting, force-stopping apps, disabling packages, clearing data/cache, changing settings, and deleting SMB files all require explicit approval.
3. **Do not uninstall or disable packages as a first fix.** Propose those only after evidence and with clear rollback instructions.
4. **Do not treat SMB as a performance diagnostic substitute.** SMB can confirm shares/reachability, but ADB is required for CPU/RAM/thermal evidence.
5. **Preserve ADB keys.** If rotating `~/.android/adbkey`, move keys to a timestamped backup; never delete them outright.

## Standard Workflow

### 1. Establish target and tools

- Use the user-provided IP. If none is provided, ask for the Shield IP. Do not hardcode a private IP address in persistent notes or skill content.
- Check ADB availability before attempting diagnostics.
- If ADB is missing, ask before installing `android-platform-tools`.
- Check reachability and relevant ports:

```bash
host=<shield-ip>
ping -c 2 -W 1000 "$host"
for port in 5555 445 139; do nc -vz -G 3 "$host" "$port"; done
```

Use context-mode (`ctx_execute`) for commands that may return more than a few lines.

### 2. Connect over ADB

```bash
host=<shield-ip>:5555
adb connect "$host"
adb devices -l
```

Interpret device states:

| State | Meaning | Next action |
|------|---------|-------------|
| `device` | Authorized and usable | Continue to baseline diagnostics |
| `unauthorized` | Shield has not accepted this ADB key | Ask user to approve prompt; if no prompt, follow auth recovery below |
| missing/offline | ADB not connected cleanly | Reconnect, check network debugging, verify IP/port |

### 3. Recover ADB authorization systematically

If `adb devices` shows `unauthorized`:

1. Ask the user to approve the Shield prompt and check **Always allow from this computer**.
2. If no prompt appears, force a reconnect:

```bash
adb disconnect "$host"
sleep 2
adb connect "$host"
adb devices -l
```

3. Restart local ADB:

```bash
adb kill-server
sleep 2
adb start-server
adb connect "$host"
```

4. Ask the user to toggle Shield Developer Options:
   - Turn Network debugging / USB debugging off and on.
   - Use Revoke USB debugging authorizations if present.

5. Only with user approval, rotate the local ADB key by backing it up first:

```bash
backup_dir="$HOME/.android/adbkey-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir"
for f in "$HOME/.android/adbkey" "$HOME/.android/adbkey.pub"; do
  [ -f "$f" ] && mv "$f" "$backup_dir/"
done
adb kill-server
adb start-server
adb connect "$host"
```

If rotation fails, restore the old key from the backup and retry. Do not keep rotating keys blindly.

### 4. Collect baseline read-only diagnostics

Run one compact snapshot. Keep output summarized.

```bash
host=<shield-ip>:5555
adb connect "$host" || true
state=$(adb devices | awk -v h="$host" '$1==h {print $2}')
echo "ADB_STATE=${state:-missing}"
[ "$state" = device ] || exit 0

adb -s "$host" shell 'printf "model="; getprop ro.product.model; printf "android="; getprop ro.build.version.release; printf "build="; getprop ro.build.display.id; printf "uptime="; cat /proc/uptime'
adb -s "$host" shell 'df -h / /data /sdcard 2>/dev/null || df -h'
adb -s "$host" shell 'grep -E "^(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree|Dirty):" /proc/meminfo; dumpsys meminfo 2>/dev/null | grep -E "^(Total RAM| Free RAM| Used RAM| Lost RAM| ZRAM| RAM:)" | head -30 || true'
adb -s "$host" shell 'dumpsys cpuinfo 2>/dev/null | head -40 || true'
adb -s "$host" shell 'dumpsys meminfo 2>/dev/null | sed -n "/Total PSS by process:/,/Total PSS by OOM adjustment:/p" | head -50 || true'
adb -s "$host" shell 'dumpsys thermalservice 2>/dev/null | grep -E "Thermal Status|Temperature\{|CoolingDevice" | head -30 || true'
adb -s "$host" shell 'pm list packages -3 2>/dev/null | sed "s/^package://" | sort'
adb -s "$host" shell 'logcat -d -t 500 2>/dev/null | grep -Ei "(ANR|ActivityManager.*Killing|LowMemory|low memory|lmkd|watchdog|thermal|FATAL EXCEPTION|force finishing)" | tail -50 || true'
```

For suspected transient CPU spikes, take 3 samples around 5 seconds apart before drawing conclusions.

### 5. Interpret common signals

| Signal | Interpretation |
|------|----------------|
| `MemAvailable` under ~500MB on a 2GB Shield | Significant memory pressure |
| Swap mostly used / low `SwapFree` | Memory pressure has accumulated; reboot may help |
| `dumpsys meminfo` status `critical` | RAM pressure is severe |
| CPU load persistently near/above core count or one app repeatedly high | Investigate that app/service first |
| `Thermal Status: 0`, CPU/GPU under ~65°C | Not thermal throttling |
| `/data` above ~85-90% | Storage pressure may affect updates/cache/app behavior |
| Recent ANR/LMKD/watchdog lines | Stability/performance issue needs targeted investigation |

Known context from the June 2026 Shield session:

- Device: `SHIELD Android TV`, Android 11, build `RQ1A.210105.003.7825199_4387.0822`.
- Pre-reboot symptoms included low/critical RAM, heavy swap use, and CPU load around 2.37.
- `com.spocky.projengmenu` / Projectivy Launcher was a top CPU consumer before reboot.
- SmartTube and NVIDIA SMB services consumed more memory before reboot than after.
- Thermals were normal and not the bottleneck.
- Reboot improved available memory, swap free, CPU load, and background process pressure.

Treat these as historical clues, not permanent truth: always re-sample current state.

### 6. Recommend actions based on evidence

Safe first recommendations usually include:

- Reboot if memory/swap pressure has accumulated.
- Re-sample after reboot to prove improvement.
- If a launcher or app remains a repeated CPU/RAM offender, ask before force-stopping it for an A/B test.
- If SMB is not actively needed, consider turning Shield SMB sharing off to save background resources.
- If storage is high, identify large apps/media before deleting anything.

Avoid speculative optimization lists. Tie each recommendation to an observed metric.

### 7. After-action comparison

After any approved reboot or tweak, collect the same key metrics and compare:

- Uptime / boot completed.
- `MemAvailable`, free RAM, swap free.
- CPU load and top CPU processes.
- Top PSS processes.
- Thermal status and temperatures.
- Recent ANR/LMKD/watchdog signals.

Report as before → after values. Example:

```text
MemAvailable: 452MB → 659MB
SwapFree: 125MB → 209MB
CPU load: 2.37 → 0.52
Thermals: unchanged, no throttling
```

## Communication Pattern

- Say what is being checked and whether it is read-only.
- When blocked by ADB auth, explain the exact state (`unauthorized`, `offline`, etc.) and give one concrete next step.
- Before a state-changing command, ask explicitly: “Do you want me to reboot / force-stop / change this setting now?”
- Final summary should distinguish facts, likely causes, and proposed next actions.

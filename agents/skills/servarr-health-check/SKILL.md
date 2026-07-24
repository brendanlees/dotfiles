---
name: servarr-health-check
description: Use when checking servarr stability, Plex/rclone FUSE hangs, kernel panics, D-state probes, Arr queues, Kometa sync state, recent imports, or whether media automation is healthy.
---

# Servarr Health Check

## Overview

Perform a read-only operational health check of `servarr` focused on the known Plex/Sonarr/Radarr ↔ rclone FUSE failure mode, Kometa tag-sync debounce, and media import flow.

**Core principle:** verify before reassurance. Do not say “stable”, “no panics”, or “working” until boot continuity, kernel logs, D-state processes, queues, and Kometa state have been checked.

## Mandatory First Steps

1. Activate/check Serena project onboarding if not already done.
2. Use read-only SSH commands only.
3. Do **not** read/probe media file contents through `/media/mRemote`, `/media/mRemote/mounts/nzbdav`, or nzbdav `.ids` paths.
4. Do not print Plex tokens, Arr API keys, Discord webhooks, or full secrets.

## Standard Check

Run a compact snapshot:

```bash
ssh servarr 'printf "=== uptime / boots ===\n"; date; uptime; journalctl --list-boots | tail -5; printf "=== dstate/probes ===\n"; ps -eo pid,ppid,stat,comm,args | awk '\''$3 ~ /D/ || /Plex Media Scan|ffprobe|ffmpeg|Sonarr|Radarr|rclone/ {print}'\'' | head -80; printf "=== kernel hung/panic current boot ===\n"; journalctl -k -b 0 --no-pager | grep -Ei '\''hung_task|blocked for more than|kernel panic|not syncing|I/O error|fuse.*error|rclone'\'' | tail -80 || true; printf "=== arr queues ===\n"; for app_port in radarr:7878 sonarr:8989; do app=${app_port%:*}; port=${app_port#*:}; key=$(grep -oPm1 "(?<=<ApiKey>)[^<]+" /home/xbxd/docker/data/$app/config.xml); echo ---$app---; curl -fsS -H "X-Api-Key: $key" "http://localhost:$port/api/v3/queue?page=1&pageSize=200" | jq -r '\''"queue_records=" + (.records|length|tostring) + " states=" + ([.records[]?.trackedDownloadState] | group_by(.) | map((.[0]//"null")+":"+(length|tostring)) | join(","))'\''; done; printf "=== kometa/hung monitor ===\n"; find /home/xbxd/docker/data/kometa/config/sync-state -maxdepth 3 -type f -printf '\''%TY-%Tm-%Td %TH:%TM:%TS %p size=%s\n'\'' 2>/dev/null | sort || true; tail -20 /var/log/hung-task-monitor.log 2>/dev/null || true'
```

If context-mode local storage errors, use direct SSH only if the harness allows read-only bash. Never “fix” by probing media files.

## Interpret Results

| Signal | Meaning | Response |
|---|---|---|
| Current boot unchanged, high uptime | Good | Mention uptime and no new boot |
| Kernel log empty for hung/panic terms | Good | “No current-boot hung-task/panic evidence” |
| D-state `Plex Media Scan`, `ffprobe`, or `ffmpeg` appears | Yellow/red | Poll briefly; if persistent near hung-task timeout, warn |
| D-state clears within a few polls | Usually OK | Note it cleared and identify item if known |
| Radarr/Sonarr queue > 0 | Not automatically bad | Report states; distinguish downloading/importPending/stuck |
| Kometa `dirty/<collection>` marker recent | Expected debounce | Do not call stuck unless older than health threshold |
| Kometa processing/drain running | Expected | Report in progress |
| Hung-task monitor shows only old 11:18 panic | Historical | Say no new monitor entries |

## Recent Media Flow Check

Use when asked whether automation is working or media was added:

```bash
ssh servarr 'bash -s' <<'REMOTE'
set -euo pipefail
since="REPLACE_WITH_UTC_ISO"
for app_port in radarr:7878 sonarr:8989; do
  app=${app_port%:*}; port=${app_port#*:}; key=$(grep -oPm1 "(?<=<ApiKey>)[^<]+" /home/xbxd/docker/data/$app/config.xml)
  echo "=== $app history since $since ==="
  curl -fsS -H "X-Api-Key: $key" "http://localhost:$port/api/v3/history?page=1&pageSize=100&sortKey=date&sortDirection=descending" \
  | jq -r --arg since "$since" '.records[]? | select(.date >= $since) | [.date,.eventType,(.movie.title//.series.title//""),(.episode.title//""),(.sourceTitle//""),(.data.importedPath//""),(.data.reason//"")] | @tsv'
done
REMOTE
```

For Plex recently-added checks, query Plex API metadata only. Do not stat/read media contents beyond directory/symlink metadata.

## Known Context

- Root issue was Plex/Sonarr `ffprobe`/scanner hangs opening rclone FUSE nzbdav symlink targets.
- Bad historical file: Parks and Recreation S04E21 “Bus Tour”; avoid restoring/importing through rclone FUSE without a safer plan.
- `hung_task_panic` normally resets to `1` after reboot.
- Arr Plex `updateLibrary` is intentionally enabled again for Radarr/Sonarr/Lidarr so Plex sees new imports before Kometa labels them.
- Kometa custom script uses dirty markers under `/home/xbxd/docker/data/kometa/config/sync-state/` and a 120s debounce.

## Response Format

Keep the answer concise:

- **Green:** no reboot, no current D-state probes, no kernel hung-task/panic, queues OK.
- **Yellow:** transient analyzer, active Kometa debounce, queue activity, or non-fatal Plex warnings.
- **Red:** new boot, current-boot hung-task/panic, persistent D-state probe, importPending with D-state `ffprobe`.

Always include the timestamp and strongest evidence, e.g. uptime, boot start, queue counts, and whether D-state/kernel checks were clean.

## Common Mistakes

- Calling Kometa “stuck” while dirty marker mtime is still changing within debounce.
- Declaring stability from uptime alone without checking D-state and kernel logs.
- Touching media contents with `ffprobe`, `dd`, `mediainfo`, `cat`, or thumbnail generation.
- Printing secrets from config/logs.
- Treating Plex `Unknown metadata type: folder` warnings as the FUSE panic pattern.

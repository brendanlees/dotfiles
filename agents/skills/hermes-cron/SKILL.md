---
name: hermes-cron
description: Use when creating, changing, troubleshooting, or handing off Hermes reminders, scheduled jobs, profile cron, recurring checks, script-backed watchdogs, or cron delivery.
---

# Hermes Cron

## Purpose

Choose the owning profile and execution path before creating scheduled work. A denied gateway write or unavailable host command is usually an expected boundary, not proof that cron is broken.

## 1. Choose the owning profile

- `default`: personal reminders, general recurring tasks, and Hermes gateway, tool, profile, or scheduler maintenance.
- `homelab`: infrastructure and service checks.
- `study`: learning reviews, practice, and study follow-ups.
- `work`: business and client schedules.

Create, list, and verify the job from its owning profile. Default-profile cron listings do not show named-profile jobs.

## 2. Choose one execution path

### Native profile cron

Use the profile-local `cronjob` tool when Hermes can perform the task directly from a prompt with tools available to that profile.

Before reporting success, verify the returned job identity, owning profile, schedule, timezone assumption, and supported delivery target. Use real Discord channel or thread IDs where required; do not assume path-like channel names resolve.

### Script-backed cron

Use this path when the job needs deterministic code, a local script, backend-only networking, or repeatable no-agent behavior.

1. Write only beneath `/workspace/dropbox/watchdogs/` or the approved `hermes-artifacts/code/watchdogs/` staging root.
2. Test from the SSH backend without exposing credentials.
3. Ask the operator to run `scripts/install-hermes-noagent-watchdog.sh` for the owning profile.
4. Wait for the operator to report successful promotion, scheduler smoke, and the resulting profile-local job identity.

Preparing a handoff does not mean the job exists.

## 3. Check dependency zones

Identify where every required file, environment name, credential reference, DNS route, and network route exists:

- profile gateway or profile-local integration;
- shared SSH terminal backend; or
- neither, requiring operator review.

Interactive success under `/workspace` does not prove gateway cron success. Backend-only dependencies need an existing approved bridge pattern. Do not request broad gateway access to make a cron job work.

## Expected boundaries

Treat these as handoff conditions rather than bypass invitations:

- inability to write the profile's `HERMES_HOME/scripts` directory;
- inability to run Docker or host-side installers;
- inability to inspect another profile's cron store;
- inability to use backend-only environment values from gateway cron.

Do not use path traversal, absolute destination paths, symlink escapes, or another profile's scheduler state. Do not create a global duplicate to work around a profile-local failure.

Treat a missing declared `cronjob` tool, rejected valid schedule, authorized creation failure, installer validator disagreement, or failed scheduler smoke as a genuine failure. Report sanitized evidence and stop.

## Script-backed operator handoff

Provide:

- owning profile;
- staged relative source path and intended `watchdogs/...` destination;
- job name and purpose;
- schedule and timezone assumption;
- supported delivery target;
- required environment names as names or `SET`/`MISSING` states only;
- backend test command and sanitized result;
- expected healthy output, including `[SILENT]` where applicable;
- request to run the existing profile watchdog installer;
- requested post-install job identity and smoke result.

Never print secret values, complete environments, profile YAML, or cron stores. Stop on ambiguous ownership, dependency-zone uncertainty, malformed schedules, failed tests, failed smoke checks, or policy/runtime disagreement.

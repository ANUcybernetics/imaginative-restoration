---
id: TASK-14
title: Fix GLIBC version mismatch preventing imgres machines from booting
status: To Do
assignee: []
created_date: '2026-04-17 03:18'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The deployed image cannot boot because the BEAM runtime requires a newer
glibc than the Fly runtime image provides. The current `mise.toml` pins
Erlang 28.1.1 / Elixir 1.18.4-otp-28, and OTP 28's BEAM binaries link
against `GLIBC_2.38`. The Fly runtime base image (likely `debian:bookworm`
which ships glibc 2.36) doesn't satisfy this.

The bug has been latent since the v103 deploy on 2026-03-02 --- the
machine kept running on its initial boot and never had to restart, so
nobody noticed. It surfaced on 2026-04-17 when a `fly secrets set`
triggered a rolling restart, and the new machine failed with:

    /app/erts-16.2.1/bin/epmd: /lib/x86_64-linux-gnu/libc.so.6:
      version `GLIBC_2.38' not found
    /app/erts-16.2.1/bin/beam.smp: /lib/x86_64-linux-gnu/libm.so.6:
      version `GLIBC_2.38' not found

Until this is fixed the imgres app cannot boot. The Fly secret rotation
that exposed the bug is unrelated to the cause and should not be reverted.

## Fix

Update the runtime base image in the Dockerfile to one with glibc >= 2.38.
Options:

- `debian:trixie-slim` (glibc 2.39, current Debian testing/13)
- `ubuntu:24.04` (glibc 2.39)

Keep the build stage on the same Debian/Ubuntu major as the runtime to
avoid drift. Verify by triggering a `fly deploy` and confirming the
machine boots and serves requests.

Optionally consider downgrading to OTP 27 if a newer base image isn't
desirable, but bumping the base is the cleaner long-term fix.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Dockerfile runtime base image upgraded to one providing glibc 2.38+
- [ ] #2 fly deploy succeeds and machine reaches running state
- [ ] #3 imgres.fly.dev returns the basic-auth challenge on a GET /
- [ ] #4 fly logs show no GLIBC version errors during boot
<!-- AC:END -->

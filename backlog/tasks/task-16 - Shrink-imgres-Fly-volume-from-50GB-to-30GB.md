---
id: TASK-16
title: Shrink imgres Fly volume from 50 GB to 30 GB
status: To Do
assignee: []
created_date: '2026-05-17 05:25'
labels:
  - infra
  - fly
dependencies: []
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The `imgres` volume was extended from 30 GB → 40 GB → 50 GB on 2026-05-16
during the VACUUM run, to leave room for SQLite's temp file (the VACUUM
needed ~2× the DB size in scratch space). After VACUUM and a DROP COLUMN
follow-up, the DB sits at ~12 GB, so the 50 GB allocation is wasteful.

Fly volumes only extend — they cannot shrink. To reclaim the size we have
to migrate the data to a new smaller volume and destroy the old one.

The easy path (mount both volumes on one machine, `cp` across) doesn't
work because Fly limits machines to a single volume. The viable options
are below; option 1 is the recommendation.

### Option 1 — Tigris S3 as a staging area (recommended)

Tigris is in the same Fly network as the app, so transfers run at
internal-network speed (~10 min each way for 12 GB rather than the
multi-hour residential-internet equivalent). The app already has Tigris
credentials (used for the audio asset).

Rough sequence:

```
# 1. take a fresh snapshot of vol_re2pezwznmjene5r as a safety net
fly volume snapshots create vol_re2pezwznmjene5r -a imgres

# 2. on the live machine, upload the DB to Tigris from an `eval`:
fly ssh console -a imgres -C '/app/bin/imaginative_restoration eval "
  ImaginativeRestoration.Utils.upload_to_s3!(...)
  # or, more direct:
  bytes = File.read!(\"/mnt/imgres/imgres.db\")
  Req.new() |> ReqS3.attach() |> Req.put!(
    url: \"s3://imaginative-restoration-sketches/migration/imgres.db\",
    body: bytes
  )
"'

# 3. stop machine, destroy machine, create new 30 GB volume named imgres_v2
fly machine stop <id> -a imgres
fly machine destroy <id> -a imgres
fly volume create imgres_v2 -a imgres --size 30 --region syd --yes

# 4. update fly.toml mount source to 'imgres_v2', deploy
#    (the new production machine attaches imgres_v2 empty)
fly deploy --remote-only

# 5. on the new machine, download the DB from Tigris into /mnt/imgres
fly ssh console -a imgres -C '/app/bin/imaginative_restoration eval "
  resp = Req.new() |> ReqS3.attach() |> Req.get!(
    url: \"s3://imaginative-restoration-sketches/migration/imgres.db\"
  )
  File.write!(\"/mnt/imgres/imgres.db\", resp.body)
"'

# 6. restart the machine so SQLite picks up the new DB file
fly machine restart <id> -a imgres

# 7. verify the kiosk loads and the most recent sketch displays

# 8. destroy old volume + clean up S3 staging file
fly volume destroy vol_re2pezwznmjene5r -a imgres --yes
# delete s3://imaginative-restoration-sketches/migration/imgres.db
```

Risks:

- The DB in S3 may differ from on-disk by a few seconds of writes if the
  app is live during step 2. Stopping the Sweeper and the LV before the
  upload (or stopping the whole machine cleanly and running step 2 via a
  one-off ephemeral machine attached to the old volume) eliminates this.
- If step 5 fails partway, the new volume has a half-written DB. The
  snapshot from step 1 is the recovery: destroy the new volume, recreate
  one from the snapshot, switch fly.toml back.

### Option 2 — Local SFTP staging (simpler, slower)

Same shape as option 1, but use `fly ssh sftp get` / `put` to move the
DB through your local machine. No custom Elixir code, but the 12 GB
round-trip over residential internet takes ~1-2 hours depending on
upload speed.

### Why not bother

Saving ~$1.50/month at Fly's current volume pricing — about $18/year.
Worth doing during a planned maintenance window; not worth doing
opportunistically.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 New 30 GB volume `imgres` (or `imgres_v2` then renamed) holds the production DB
- [ ] #2 Production machine attached to the new volume, kiosk loads, most recent sketch displays
- [ ] #3 Old 50 GB volume destroyed
- [ ] #4 Any staging artefacts in Tigris cleaned up
<!-- AC:END -->

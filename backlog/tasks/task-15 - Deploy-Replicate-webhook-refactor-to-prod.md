---
id: TASK-15
title: Deploy Replicate webhook refactor to prod
status: To Do
assignee: []
created_date: '2026-05-15 22:42'
labels:
  - deploy
  - replicate
  - webhook
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Push the webhook refactor to fly.io and verify the end-to-end pipeline works in prod.

The refactor replaces the polling-based Replicate client with fire-and-forget submissions plus a webhook callback. Before deploy, the Replicate webhook signing secret needs to be set as a fly secret so signature verification works (otherwise the controller logs a warning and accepts unsigned requests — convenient for debugging but bad for prod).

The migration (20260515105227_webhook_refactor) adds state/prediction_id/intermediate_image/error columns; existing rows are backfilled to state=:succeeded via the column default.

Runbook:

    # 1. Log in (one-time)
    flyctl auth login

    # 2. Fetch the webhook signing secret from Replicate
    curl -s -H "Authorization: Bearer $(fnox get REPLICATE_API_TOKEN)" \
      https://api.replicate.com/v1/webhooks/default/secret
    # → { "key": "whsec_xxxxx" }

    # 3. Set it on fly
    flyctl secrets set REPLICATE_WEBHOOK_SECRET=whsec_xxxxx

    # 4. Deploy (runs the migration)
    flyctl deploy

    # 5. Tail logs while testing one drawing
    flyctl logs

Fallback for debugging: if every webhook returns 401 ("Rejected Replicate webhook ... :invalid_signature"), `flyctl secrets unset REPLICATE_WEBHOOK_SECRET` will bypass verification so you can isolate signature bugs from extraction bugs.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 REPLICATE_WEBHOOK_SECRET is set on fly (verify with flyctl secrets list)
- [ ] #2 flyctl deploy succeeds and the webhook_refactor migration is applied
- [ ] #3 End-to-end: one drawing produces one sketch that reaches state=:succeeded with a processed image
- [ ] #4 flyctl logs shows no :invalid_signature rejections and no Unexpected output shape errors during the e2e test
- [ ] #5 The Sweeper does not log warnings about stuck sketches under normal operation
<!-- AC:END -->

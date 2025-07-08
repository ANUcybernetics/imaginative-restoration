---
id: task-3
title: Consolidate /prompts and /config endpoints into one page
status: To Do
assignee: []
created_date: "2025-07-08"
labels: []
dependencies: []
priority: medium
---

## Description

Looking at the @lib/imaginative_restoration_web/router.ex there are separate
/prompts and /config endpoints. I'd like to consolidate them into a single
`admin` endpoint/view which:

- showed the most recent Sketch pipeline results (both input and output images)
- showed a live "webcam stream" view with the current crop box drawn on top of
  the video (in the appropriate spot) to indicate where the crop will be applied
- show current free/used disk space on the host
- give some sort of indication of the inter-capture frame differences (in
  numerical terms), to help with calibrating the threshold to use in
  `frame_difference/2` in @lib/imaginative_restoration_web/live/app_live.ex

---
id: task-3
title: Consolidate /prompts and /config endpoints into one page
status: Done
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

## Implementation Notes

Created a new consolidated `AdminLive` module at `/admin` that includes:

1. **Recent Sketch Pipeline Results**: Shows the last 5 sketches with both input and output images, with real-time updates via Phoenix PubSub
2. **Live Webcam Stream**: Displays the webcam feed with a crop box overlay (currently hardcoded at 350px, 100px with 120x120 dimensions - this should be made configurable)
3. **Disk Space Monitoring**: Shows current disk usage with free/used/total space and a visual progress bar, updates every 30 seconds
4. **Frame Difference Calibration**: Shows inter-frame distances with color coding (red = exceeds threshold, green = below threshold) to help calibrate the `image_difference_threshold`
5. **Prompt Examples**: Displays sample prompts that are dynamically generated

The old `/config` and `/prompts` endpoints have been removed from the router and replaced with the single `/admin` endpoint.

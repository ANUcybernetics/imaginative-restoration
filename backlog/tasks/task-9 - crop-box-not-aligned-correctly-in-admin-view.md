---
id: task-9
title: crop box not aligned correctly in admin view
status: Done
assignee: []
created_date: '2025-07-08'
updated_date: '2025-07-08'
labels: []
dependencies: []
---

## Description

on the admin view (on desktop, at least) the red "crop box" indicator isn't even
drawn on the live video feed.

I want it to be exactly where the crop will happen. Draw the box in the js hook
if that's the best way to do it.

## Implementation Notes

Fixed by:
1. Removed the hardcoded crop box div from `admin_live.ex`
2. Added a `crop-box-overlay` container div for JavaScript to draw into
3. Added `show_full_frame` boolean attribute to the `webcam_capture` component
4. Updated `webcam_stream_hook.js` to:
   - Check for presence of `data-show-full-frame` attribute (idiomatic HEEx pattern)
   - Show full video frame when attribute is present (admin view)
   - Show cropped canvas when attribute is absent (main app)
   - Draw crop box overlay on the full frame to show exact crop area
5. Added window resize handling to keep the overlay aligned

The admin view now shows the full webcam frame with a red crop box overlay indicating the exact area that will be captured, while the main app continues to show only the cropped area.

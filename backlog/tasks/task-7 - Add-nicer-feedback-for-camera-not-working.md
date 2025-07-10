---
id: task-7
title: Add nicer feedback for camera not working
status: Done
assignee: []
created_date: "2025-07-08"
labels: []
dependencies: []
parent_task_id: task-5
priority: medium
---

## Description

If the camera stream in the main app view isn't working for some reason (e.g. no
camera detected, or no permission given), display an error indicator in the
place where the webcam stream would otherwise be displayed.

## Completion Notes

Implemented comprehensive camera error handling:

1. **Camera error detection and display** - Added visual feedback when camera fails
2. **Admin view enhancements**:
   - Split view showing both live feed with crop box overlay and cropped preview
   - Fixed letterboxing issues with proper aspect ratio calculations
   - Added `phx-update="ignore"` to prevent LiveView from clearing overlays
   - Grid and crop box now properly align with actual video content area

The admin view now shows:
- Left panel: Live video feed with continuously updated grid and crop box
- Middle panel: Cropped image preview (or placeholder if no capture_box param)
- Right panel: Frame difference calibration metrics

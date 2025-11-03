---
id: task-13
title: Simplify AppLive frame processing using start_async
status: To Do
assignee: []
created_date: '2025-11-03 11:02'
labels:
  - bug
  - refactor
  - phoenix-liveview
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The current frame capture and processing logic in AppLive uses manual flag management (is_processing, last_processed_frame, skip_process?) which is prone to race conditions. When processing fails or crashes, the is_processing flag can get stuck, causing the system to stop processing new frames until the page is refreshed.

Replace this with Phoenix LiveView's built-in start_async/3 which:
- Automatically handles task lifecycle and crashes
- Cancels previous in-flight tasks when new ones start (perfect for our use case where only the latest frame matters)
- Eliminates all manual state management
- Much simpler and more robust

Files to modify:
- lib/imaginative_restoration_web/live/app_live.ex
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Remove is_processing, last_processed_frame, skip_process? from socket state
- [ ] #2 Replace handle_capture_frame logic to use start_async(:process_frame, fn -> ... end)
- [ ] #3 Add handle_async(:process_frame, {:ok, _}, socket) for successful completion
- [ ] #4 Add handle_async(:process_frame, {:exit, reason}, socket) for crash handling
- [ ] #5 Remove start_processing_task/1 helper function
- [ ] #6 Remove :processing_complete message handler
- [ ] #7 System correctly processes frames and recovers from failures without manual intervention
<!-- AC:END -->

---
id: task-13
title: Simplify AppLive frame processing using start_async
status: Done
assignee: []
created_date: '2025-11-03 11:02'
updated_date: '2026-05-15 22:46'
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
- [x] #1 Remove is_processing, last_processed_frame, skip_process? from socket state
- [x] #2 Replace handle_capture_frame logic to use start_async(:process_frame, fn -> ... end)
- [x] #3 Add handle_async(:process_frame, {:ok, _}, socket) for successful completion
- [x] #4 Add handle_async(:process_frame, {:exit, reason}, socket) for crash handling
- [x] #5 Remove start_processing_task/1 helper function
- [x] #6 Remove :processing_complete message handler
- [x] #7 System correctly processes frames and recovers from failures without manual intervention
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Done as part of the Replicate webhook refactor (lib/imaginative_restoration_web/live/app_live.ex). Socket state now uses current_sketch_id (nil | :pending | integer) instead of is_processing / last_processed_frame / skip_process?. Frame submission goes through start_async(:submit, ...) with matching handle_async clauses for {:ok, sketch} and {:exit, reason}. start_processing_task/1 and :processing_complete are gone. Note: the async name in the implementation is :submit rather than :process_frame because the action now fire-and-forgets to Replicate via webhook rather than waiting for processing to complete.
<!-- SECTION:NOTES:END -->

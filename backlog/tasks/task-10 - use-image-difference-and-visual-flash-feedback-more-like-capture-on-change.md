---
id: task-10
title:
  use image difference and visual flash feedback more like capture on change
status: Done
assignee: []
created_date: "2025-07-11"
labels: []
dependencies: []
---

## Description

Currently the @lib/imaginative_restoration_web/live/app_live.ex view runs on a
slow-ish (configurable, but 20s is the default) capture interval. There's a
visual indicator (the "progress-line") in @assets/js/webcam_stream_hook.js which
shows the time until the next capture.

In addition, the app does some "frame differencing" (using an
:image_difference_threshold config key) to not re-process the image if it hasn't
changed enough.

The interaction of these two features is a bit unsatisfying... the user has to
wait a while for the next capture to trigger, but the flash overlay doesn't
always show up immediately after the capture. And if the capture is "skipped"
due to frame difference, the UI isn't very clear about this.

The proposed change is this:

- have the capture interval much shorter (e.g. 1s)
- _don't_ have the "process line" at all
- _do_ have the flash overlay trigger if the threshold is cleared and the
  capture happens (and the image is processed)
- _then_ if the processing is happening, don't check the frame (and potentially
  capture/process a new image) for a longer period, e.g. 20s (this is because
  the remote processing pipeline often takes up to 15s)

One limitation of this is that the frame differencing happens on the server, so
the message to "flash" the overlay on the client hook would need to be
communicated back somehow. One alternative is to do the frame differencing on
the client, but I'm not sure if that would require a bunch of extra js libs and
complicate the codebase too much.

## Feedback

### Strengths of the Approach

- **Better UX**: The continuous monitoring with fast intervals (1s) will make
  the app feel more responsive
- **Clear feedback**: Flash only on actual capture/processing provides
  unambiguous feedback
- **Resource efficiency**: The 20s cooldown prevents overwhelming the processing
  pipeline

### Considerations

1. **Server-side differencing trade-offs**:

   - Pro: Keeps client lightweight, centralizes logic
   - Con: Requires server->client messaging for flash trigger
   - Solution: Use Phoenix PubSub to push a `"capture_triggered"` event to the
     LiveView

2. **Client-side differencing alternative**:

   - Could use Canvas API to compare frames without external libs
   - Simple pixel sampling might be sufficient (no need for full image diff
     libraries)
   - Would eliminate server round-trip for non-captures

3. **Hybrid approach suggestion**:

   - Do rough differencing client-side (e.g., sample 100 pixels)
   - If change detected, send frame to server for final validation
   - Server does precise differencing and triggers processing if needed

4. **Edge cases to handle**:
   - What if processing takes >20s? Queue or skip?
   - Network interruptions during the 1s intervals
   - Multiple users viewing the same stream

### Implementation Path

1. Start with server-side approach (simpler, follows current architecture)
2. Add Phoenix Channel event for flash trigger
3. Monitor performance impact of 1s intervals
4. Consider client-side optimization if server load becomes an issue

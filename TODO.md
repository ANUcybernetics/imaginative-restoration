## TODO

- sort out auto-updates for macOS (plus VNC)
- check the script re-starts when power is cycled
- change the "skip processing" logic to only skip if 5 in a row are the same
  (possibly with a `skipped_count` int counter or something)
- update the y-axis range for the things that float across the screen

### Future

- (maybe) consolidate `/prompts` and `/config` endpoints into one page (and add
  DB disk space status, perhaps other metrics)
- download DB (for backup)
- add nicer feedback for camera not working, or processing pipeline failed (e.g.
  http error), or missing capture box params, or no AUTH_USERNAME...

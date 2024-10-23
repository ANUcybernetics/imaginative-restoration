# ImaginativeRestoration

TODO copy description from the other `README.md`.

## TODO

- webp (and compression?) for final images
- add "no change to sketch" detection
- maybe ditch Oban, just use Task.async
- flocking behaviour for sketches
- add canny filter (client-side?)
- add animated "capturing" widget for top-right, with countdown and sfx
- deploy to fly.io
- make the nfsa film grow to fill the width (or height) even if it's bigger than
  actual size while preserving letterboxing
- rename old `main` branch to `jetson`, move `web` branch to `main` (maybe
  rebase? but probs not)

- read-only views (for outside the grotto)
- scheduler (i.e. only run during business hours)
- crop image based on bb before AI-ifying? probably not, though

## nomenclature

- each image is a sketch (unprocessed or processed)
- the video area is the canvas

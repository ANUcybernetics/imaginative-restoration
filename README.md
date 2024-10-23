# ImaginativeRestoration

TODO copy description from the other `README.md`.

## TODO

- set cache control on the video so it's cached
- update js hook to screencap and send event to server liveview process
- draw images on canvas
- crop image based on bb before AI-ifying?
- webp (and compression?) for final images
- add "no change to sketch" detection
- add sketch->processed models, randomise
- flocking behaviour for sketches
- add canny filter (client-side?)
- add animated "capturing" widget for top-right, with countdown and sfx
- deploy to fly.io
- rename old `main` branch to `jetson`, move `web` branch to `main` (maybe
  rebase? but probs not)

- read-only views (for outside the grotto)
- scheduler (i.e. only run during business hours)

## nomenclature

- each image is a sketch (unprocessed or processed)
- the video area is the canvas

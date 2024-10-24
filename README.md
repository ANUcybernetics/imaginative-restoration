# ImaginativeRestoration

TODO copy description from the other `README.md`.

## TODO

- when storing processed/raw images, store them as data URLs
- add a "processing" indicator, or something to indicate when the pipeline is
  complete (maybe need to use the actual Sketch object in assigns)
- check whether the webcam image cropping is actually working
- add "raw", "cropped" and "processed" image views (check need for squareness)
- trigger the webcam capture from the server (maybe?)
- use the florence BB (the first BB one) to crop (and maybe draw that in the
  pipeline indicator too, with label)
- add "no change to sketch" detection
- flocking behaviour for sketches
- fade from bg to colour
- add animated capture widget with countdown, sfx, and "processing pipeline"
  indicator
- deploy to fly.io
- make the nfsa film grow to fill the width (or height) even if it's bigger than
  actual size while preserving letterboxing
- rename old `main` branch to `jetson`, move `web` branch to `main` (maybe
  rebase? but probs not)

- nice feedback for:

  - camera not working
  - processing pipeline failed

- read-only views (for outside the grotto)
- add canny filter (client-side?)
- scheduler (i.e. only run during business hours)

## nomenclature

- each image is a sketch (raw or processed)
- the video area is the canvas

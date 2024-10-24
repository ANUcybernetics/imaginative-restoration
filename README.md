# ImaginativeRestoration

TODO copy description from the other `README.md`.

## TODO

- when storing processed/unprocessed images, store them as data URLs
- check whether the webcam image cropping is actually working
- use the florence BB (the first BB one) to crop (and maybe draw that in the
  pipeline indicator too, with label)
- add "no change to sketch" detection
- flocking behaviour for sketches
- fade from bg to colour
- add canny filter (client-side?)
- add animated capture widget with countdown, sfx, and "processing pipeline"
  indicator
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

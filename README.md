# ImaginativeRestoration

TODO copy description from the other `README.md`.

## TODO

- add a "processing" indicator, or something to indicate when the pipeline is
  complete (maybe need to use the actual Sketch object in assigns)
- trigger the webcam capture from the server (maybe?)
- handle any HTTP errors from Replicate
- add "no change to sketch" detection
- flocking behaviour for sketches
- fade from bg to colour
- add animated capture widget with countdown, sfx, and "processing pipeline"
  indicator
- deploy to fly.io
- rename old `main` branch to `jetson`, move `web` branch to `main` (maybe
  rebase? but probs not)

- nice feedback for:

  - camera not working
  - processing pipeline failed

- select at random from the florence-detected objects, not always the first one
- read-only views (for outside the grotto)
- add canny filter (client-side?)
- scheduler (i.e. only run during business hours)

## nomenclature

- each image is a sketch (raw or processed)
- the video area is the canvas

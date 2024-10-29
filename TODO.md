## TODO

- make sketches flock around the canvas as they come in
- fade sketches from bg to colour
- add "no change to sketch" detection
- deploy to fly.io
- get the final cut of the film (including soundtrack)
- add scheduler (i.e. only run during business hours)
- test with 1080p camera 873mm above desk, slightly-smaller-than-A3 surface
- add nicer feedback for camera not working, or processing pipeline failed (e.g.
  http error), or missing capture box params

## Ideas

Not necessarily good ones, but things we might try:

- trigger the webcam capture from the server
- image->video (because Charlotte has a bee in her bonnet about it)
- select at random from the florence-detected objects, not always the first one
- add read-only views (for outside the grotto, or anywhere in the world)

## Helpful scripts

```elixir
# http://127.0.0.1:4000/100,120,460,320
capturebox = [100,120,460,320]

ImaginativeRestoration.Sketches.Sketch
|> Ash.read!
|> Enum.each(& &1.processed && &1.processed |> ImaginativeRestoration.AI.Utils.to_image! |> Image.write!("/tmp/ir-sketches-processed/#{&1.id}.webp"))
```

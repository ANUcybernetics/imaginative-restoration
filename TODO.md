## TODO

- debugging: why does the boid canvas get resized (and borked) when the
  "frame_data" event is pushed to the server? check if it's the pushing that
  matters, or whatever the result is

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
capturebox = [100,120,460,320]

ImaginativeRestoration.Sketches.Sketch
|> Ash.read!
|> Enum.each(& &1.processed && &1.processed |> ImaginativeRestoration.AI.Utils.to_image! |> Image.write!("/tmp/ir-sketches-processed/#{&1.id}.webp"))
```

## TODO

- animate pipeline view
- just use a couple of the clips
- add an LLM in there to make the pictures conform to the scene a bit more
- deploy to fly.io
- add scheduler (i.e. only run during business hours)
- test with 1080p camera 873mm above desk, slightly-smaller-than-A3 surface
- add nicer feedback for camera not working, or processing pipeline failed (e.g.
  http error), or missing capture box params

## Ideas

Not necessarily good ones, but things we might try:

- fade sketches from bg to colour
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

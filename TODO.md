## TODO

- web interface for changing prompt/model (inc. gallery of "example" sketches)
- further animate image size/opacity/tint/filter
- add the inside/outside views
- pre-load last _n_ (even on startup)
- resize sketch.img on creation (to be a normal "max" size)

- add test for "changed_recently?" logic
- just use a couple of the clips
- test with 1080p camera 873mm above desk, slightly-smaller-than-A3 surface
- add nicer feedback for camera not working, or processing pipeline failed (e.g.
  http error), or missing capture box params, or no AUTH_USERNAME...

- add an LLM in the pipeline to make the pictures conform to the scene a bit
  more
- randomize the prompts, params, or model (although be careful about coldness)
- select at random from the florence-detected objects, not always the first one

- add read-only views (for outside the grotto, or anywhere in the world)

## Helpful scripts

```elixir
ImaginativeRestoration.Sketches.Sketch
|> Ash.read!
|> Enum.each(& &1.processed && &1.processed |> ImaginativeRestoration.AI.Utils.to_image! |> Image.write!("/tmp/ir-sketches-processed/#{&1.id}.webp"))
```

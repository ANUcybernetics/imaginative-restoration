## TODO

- filter out envelope label
- green & orangey/brown for the spinner, plus rounded corners?
- resize sketch.img on creation (to be a normal "max" size)
- error out if :process action called on a sketch without a label

- add test for "changed_recently?" logic
- just use a couple of the clips
- test with 1080p camera 873mm above desk, slightly-smaller-than-A3 surface
- add nicer feedback for camera not working, or processing pipeline failed (e.g.
  http error), or missing capture box params, or no AUTH_USERNAME...

## Helpful scripts

```elixir
ImaginativeRestoration.Sketches.Sketch
|> Ash.read!
|> Enum.each(& &1.processed && &1.processed |> ImaginativeRestoration.AI.Utils.to_image! |> Image.write!("/tmp/ir-sketches-processed/#{&1.id}.webp"))
```

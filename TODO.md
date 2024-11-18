## TODO

- add audio playing code (and sfx?)
- filter out envelope label
- resize sketch.img on creation (to be a normal "max" size)

- error out if :process action called on a sketch without a label
- update "validate if attr present" things for the various pipeline actions

- setup Mac Mini
- test for multi-screen (on Mac Mini)
- add test for "changed_recently?" logic

- tweak speed of colour fade
- tweak image size & opacity over time as well

- add updated video (from Daniel)

- allow prompt-scheduling
- prompt history view

- update README
- add more instructions on how to set it up & run it

- test with 1080p camera 873mm above desk, slightly-smaller-than-A3 surface
- add nicer feedback for camera not working, or processing pipeline failed (e.g.
  http error), or missing capture box params, or no AUTH_USERNAME...

## Helpful scripts

```elixir
ImaginativeRestoration.Sketches.Sketch
|> Ash.read!
|> Enum.each(& &1.processed && &1.processed |> ImaginativeRestoration.AI.Utils.to_image! |> Image.write!("/tmp/ir-sketches-processed/#{&1.id}.webp"))
```

- `capture_box=70,90,470,300`

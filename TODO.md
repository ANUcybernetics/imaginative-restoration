## TODO

- tweak launch script to launch fullscreen on two monitors
- add test for "changed_recently?" logic

- allow prompt-scheduling
- prompt history view

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

- ``

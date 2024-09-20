# Storytellers

Software for the _Storytellers_ installation at the NFSA in October 2024. Code
mostly by Ben Swift, but check the `git log` for the real story.

## Install

It's a [rye](https://rye.astral.sh) snafu, so `rye sync` will set you up. Other
ways work too, but... [y'know](https://xkcd.com/1987/).

Note: currently set up for use on an Apple Silicon Mac, but should work with an
NVIDIA card too (in fact, would probably work better). You'll just need to grep
through the codebase and change all the `"mps"`s to `"cuda"`.

Note: video files aren't committed to this repo, because (a) we don't have the
licence to put them on GitHub and (b) they'd bloat the repo anyway. So to use
this, create your own video frames---see [the assets readme](/assets/README.md)
for more info.

## Use

1. ensure you've got your image frames in `assets/<video_name>/`
2. modify the code in `src/storytellers/__init__.py` to point at your folder of
   image frames
3. set up your webcam (might need to change the index at the top of `image.py`
   to select the right webcam)
4. `rye run storytellers` and you're away

## TODO

- add the "frame-based prompt" stuff (maybe in a JSON file?, or a dict)
- [async it](https://docs.python.org/3/library/asyncio-eventloop.html#running-and-stopping-the-loop):
  run film at real speed, but run the ai stuff as fast as possible
- camera is 873mm above desk, 4:3
- need to figure out what to put on the horizontal CRT? diagonal is?
- make it go brrrrrr (i2c, StreamDiffusion, downsize?)
- sound: Daniel to provide, but add the playback code in there
- move from using matplotlib (gross!) to probably wxPython (maybe
  [this](https://wiki.wxpython.org/WorkingWithImages)) or maybe kivy

## Licence

MIT

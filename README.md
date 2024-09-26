# Storytellers

Software for the _Storytellers_ installation at the NFSA
[Fantastic Futures](https://www.nfsa.gov.au/fantastic-futures-conference-canberra-2024)
conference in October 2024. Code in this repo by
[@benswift](https://github.com/benswift), but others have contributed sother
significant work to the overall project---writing, set design & build, archival
content, etc. The _Storytellers_ project is a collaboration between the
[NFSA](https://www.nfsa.gov.au/), [NIDA](https://www.nida.edu.au) and the
[ANU School of Cybernetics](https://cybernetics.anu.edu.au).

## Repo structure

Python workflow-wise, it's a [rye](https://rye.astral.sh) snafu, so `rye sync`
will set you up. Other ways work too, but... [y'know](https://xkcd.com/1987/).

App-wise, running the module's `main()` func will run a native (Qt6) app which
opens a fullscreen window, turns on the camera, and loops/mogrifies the film
continuously.

Note: video files aren't committed to this repo, because (a) we don't have the
licence to put them on GitHub and (b) they'd bloat the repo anyway. So to use
this, create your own video frames---see [the assets readme](/assets/README.md)
for more info.

## Use

1. ensure you've got your image frames in `assets/nfsa/`
2. set up your webcam (might need to change the index at the top of `utils.py`
   to select the right webcam)
3. `rye run python -m storytellers` and you're away

## TODO

- refactor hardcoded `mps` backend stuff to choose `cuda` if available
- add audio playback code
- add controlnet/t2i (perhaps invert the sketch)
- test with 1080p camera 873mm above desk, slightly-smaller-than-A3 surface
- put the updated prompts in `utils.FRAME_PROMPT_INDEX` (currently in
  [here](https://docs.google.com/document/d/1uNgKd9r9YIJIwN2FSylH2od6w8og2B1i38UkzmLHLvA/))
- get the final cut of the film from Daniel (and soundtrack), resize and split
  it into frames
- add cropping & keystone correction
- make it go brrrrrr (StreamDiffusion, downsize?)
- run two displays (check display splitter works)

### maybe...

- add an extra [YOLO](https://github.com/THU-MIG/yolov10) step (perhaps only
  every n frames), and then add the detected object(s) to the prompt

## Licence

MIT

# Imaginative Restoration: Re-wilding Division

In a distant future, humanity has retreated underground to escape increasingly
inhospitable surface conditions. Here, in subterranean grottos, the Storytellers
safeguard fragments of the past. But they don't merely preserve these
artefacts—they breathe new life into them through a process called Imaginative
Restoration.

_Imaginative Restoration: Rewilding Division_ is an immersive installation that
invites participants to step into the role of a Storyteller. Your mission? To
interact with and creatively restore damaged archival films from the
[National Film and Sound Archive of Australia](https://www.nfsa.gov.au/) (NFSA).
As a Storyteller in the Rewilding Division you work to dream up and repopulate
the scenes with Australian flora and fauna, by hand drawing the creatures you
can imagine, in live time you will see them enter the footage of the film,
adding colour to the black and white scenes of the past.

Storytellers is the result of an exploratory collaboration between the
[National Institute of Dramatic Arts](https://www.nida.edu.au) (NIDA), the
[National Film and Sound Archive of Australia](https://www.nfsa.gov.au/) (NFSA)
and the [School of Cybernetics](https://cybernetics.anu.edu.au) at the
Australian National University (ANU). It emerged from a workshop held in
Canberra during July 2024 where experts in dramatic writing, props and effects,
curation, and digital technologies came together to explore the future of
dramatic arts creation, recording, and archiving in the age of generative AI.

## Repo structure

This repo contains the software for the above-described installation at the NFSA
[Fantastic Futures](https://www.nfsa.gov.au/fantastic-futures-conference-canberra-2024)
conference in October 2024. Code in this repo by
[@benswift](https://github.com/benswift), but others have contributed sother
significant work to the overall project---writing, set design & build, archival
content, etc.

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

- build docker container which works on Jetson Orin AGX (see comments in
  `Dockerfile` for hints on how to proceed)
- add
  [T2I adapter (canny)](https://huggingface.co/TencentARC/t2i-adapter-canny-sdxl-1.0)
  so the generated images hew more closely to the input sketch
- make it go brrrrrr (StreamDiffusion, downsize?), perhaps by:
  - xformers
  - use StreamDiffusion tricks (there's a non-working skeleton in
    `stream_diffusers.py`, but it needs a lot of work) test
  - worst-comes-to-worst we can do some "img2img at low res, then scale up"
    tricks and things of that nature
- add audio playback code
- make it easy to turn on/off/sleep
- test & tag all electronics
- test with 1080p camera 873mm above desk, slightly-smaller-than-A3 surface
- set up for two displays (via splitter)
- put the updated prompts in `utils.FRAME_PROMPT_INDEX` (currently in
  [here](https://docs.google.com/document/d/1uNgKd9r9YIJIwN2FSylH2od6w8og2B1i38UkzmLHLvA/))
- get the final cut of the film from Daniel (and soundtrack), resize and split
  it into frames
- add cropping & keystone correction

### and maybe if we have time

- add an extra [YOLO](https://github.com/THU-MIG/yolov10) step (perhaps only
  every n frames) post-webcam, and then add any detected object(s) to the prompt

## Licence

MIT

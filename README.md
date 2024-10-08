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
On Jetson (see instructions below) it's dockerized.

App-wise, running the module's `main()` func will run a native (Qt6) app which
opens a fullscreen window, turns on the camera, and loops/mogrifies the film
continuously. Press "Q" on the keyboard to quit.

Note: video files aren't committed to this repo, because (a) we don't have the
licence to put them on GitHub and (b) they'd bloat the repo anyway. So to use
this, create your own video frames---see [the assets readme](/assets/README.md)
for more info.

## Use

1. ensure you've got your image frames in `assets/nfsa/`
2. set up your webcam (might need to change the index at the top of `utils.py`
   to select the right webcam)
3. then, on a desktop machine with the right drivers installed, you can run with

   ```sh
   rye run python -m storytellers
   ```

On the
[Jetson Orin AGX 64GB](https://www.nvidia.com/content/dam/en-zz/Solutions/gtcf21/jetson-orin/nvidia-jetson-agx-orin-technical-brief.pdf),
you'll also need to

4. build the special "base" container with `diffusers` and `transformers` in it
   using the [nvidia-jetson](https://github.com/dusty-nv/jetson-containers) tool
   with

   ```sh
   jetson-containers build --name=stjet transformers diffusers torch_tensor2trt
   ```

5. build the `storytellers` container with this actual application code in it
   with

   ```sh
   docker build . --tag storytellers
   ```

6. run `xhost +local:docker` on your host machine to allow the Docker container to connect to your X server

7. and then you can run the Qt6 app with

   ```sh
   docker run --rm -it --device=/dev/video0:/dev/video0 --env DISPLAY=$DISPLAY --volume /tmp/.X11-unix:/tmp/.X11-unix storytellers
   ```

## TODO

See [issues](https://github.com/ANUcybernetics/storytellers/issues) for the main
items, plus a few other things which haven't been written up as issues yet:

- make it easy to turn on/off/sleep
- test audio output from the jetson
- test splitter
- test & tag all electronics
- test with 1080p camera 873mm above desk, slightly-smaller-than-A3 surface
- get the final cut of the film from Daniel (and soundtrack), resize and split
  it into frames

## Development notes (Jetson Linux)

- due to the small built-in root FS on the Jetson's SD card, I followed the
  instructions [here](https://www.jetson-ai-lab.com/tips_ssd-docker.html) to put
  all the docker stuff on a (usb-attached) SSD
- ran into a few bugs along the way in
  [jetson-containers](https://github.com/dusty-nv/jetson-containers/issues/654),
  which are fixed in
  [Ben's fork](https://github.com/benswift/jetson-containers/) although
  hopefully they'll be merged back in at some point

## Licence

MIT

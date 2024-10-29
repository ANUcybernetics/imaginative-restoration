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

This repo contains the software for the above-described installation. Code in
this repo by [@benswift](https://github.com/benswift), but others have
contributed sother significant work to the overall project---writing, set design
& build, archival content, etc.

It's a web app, powered by Ash/Phoenix and written Elixir. It's hosted on
`fly.io`.

Note: there was a previous version of the project using a wholly different tech
stack (running CUDA-accelerated models locally on an NVIDIA Jetson Orin AGX).
That code is still here, but it's in the `jetson` branch (there was even a
:shudder: force push at one point). It's not actually even related (in the
strict git history-sense) to the current branch, so if you want to merge between
them you'll have a bad time. But there's some interesting stuff in that codebase
as well, and archives are about what _actually_ happened, not just the final
(usually retconned) story about how we got here.

## Licence

MIT

## TODO

- trigger the webcam capture from the server (maybe?)
- handle any HTTP errors from Replicate
- add "no change to sketch" detection
- flocking behaviour for sketches (using
  [boids](https://www.npmjs.com/package/@thi.ng/boids)
- fade from bg to colour
- add animated capture widget with countdown, sfx, and "processing pipeline"
  indicator
- deploy to fly.io
- get the final cut of the film (including soundtrack)
- add scheduler (i.e. only run during business hours)
- test with 1080p camera 873mm above desk, slightly-smaller-than-A3 surface
- add nicer feedback for camera not working, or processing pipeline failed
  (maybe flash?), or missing capture box params

## Ideas

Not necessarily good ones, but things we might try:

- select at random from the florence-detected objects, not always the first one
- add read-only views (for outside the grotto, or anywhere in the world)

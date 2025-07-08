# Imaginative Restoration: Re-wilding Division

> In a distant future, humanity has retreated underground to escape increasingly
> inhospitable surface conditions. Here, in subterranean grottos, the
> Storytellers safeguard fragments of the past. But they don't merely preserve
> these artefacts—they breathe new life into them through a process called
> Imaginative Restoration.

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

## Setup

To run this installation you'll need:

- A computer which can run Chrome (inc. keyboard & mouse for setup purposes)
- A camera (e.g. a webcam)
- Pens & paper for drawing
- A physical setup where the camera can see the "drawing area" (any flat surface where people can place their drawings in view of the camera)

### Quick Start

For macOS kiosk setup, see [kiosk/macos/README.md](./kiosk/macos/README.md).

For Raspberry Pi kiosk setup, see [kiosk/rpi/README.md](./kiosk/rpi/README.md).

### Manual Setup

If the kiosk scripts aren't working, you can run manually:

```sh
IMGRES_AUTH=user:pass ./imgres-launch.sh
```

Or visit <https://imgres.fly.dev?capture> in Chrome (enter username & password when prompted).

To configure a "crop area" for the camera, provide crop parameters (`x_offset,y_offset,width,height`) via URL:

```
https://imgres.fly.dev?capture_box=70,90,470,300
```

## Repository structure

This code repository contains the software for the project. Code in this repo by
[@benswift](https://github.com/benswift), but others have contributed sother
significant work to the overall project---writing, set design & build, archival
content, etc. See the [credits](#credits) below.

It's a web app, powered by
[Ash/Phoenix](https://hexdocs.pm/ash_phoenix/readme.html) and written
[Elixir](https://elixir-lang.org) and hosted on [fly.io](https://fly.io).

**Note**: there was a previous version of the project using a wholly different
tech stack, running CUDA-accelerated models locally on an NVIDIA Jetson Orin
AGX. That code is still in the repo, but it's in the `jetson` branch. It's not
related (in the strict git history-sense) to the current branch, so if you want
to merge between them you'll have a bad time. But there's some interesting stuff
in that codebase as well, and archives are about what _actually_ happened, not
just the final (retconned) story about how we got here.

## Credits

This creative installation was made possible by a collaboration of the ANU
School of Cybernetics, the National Film and Sound Archive and the NIDA Future
Centre. Brought to life by:

- Charlotte Bradley
- Joe Hepworth
- Daniel Herten
- Ripley Rubens
- Beth Shulman
- Ben Swift
- Lily Thomson
- Marcelo Zavala-Baeza

### Sources

- **Video loop**: _Annette Kellerman Performing Water Ballet at Silver Springs,
  Florida_ (1939) courtesy of the National Film and Sound Archive

- **Background music**:
  [Soundflakes - Horizon of the Unknown](https://freesound.org/people/SoundFlakes/sounds/592086/)
  by [SoundFlakes](https://freesound.org/people/SoundFlakes/),
  [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

- **Text-to-Image** model: Mou, Chong and Wang, Xintao and Xie, Liangbin and Wu,
  Yanze and Zhang, Jian and Qi, Zhongang and Shan, Ying and Qie, Xiaohu,
  [_T2i-adapter: Learning adapters to dig out more controllable ability for text-to-image diffusion models_](https://arxiv.org/abs/2302.08453),
  hosted on [Replicate](https://replicate.com/adirik/t2i-adapter-sdxl-canny)

- **Object detection** model: Xiao, Bin and Wu, Haiping and Xu, Weijian and Dai,
  Xiyang and Hu, Houdong and Lu, Yumao and Zeng, Michael and Liu, Ce and Yuan,
  Lu,
  [_Florence-2: Advancing a unified representation for a variety of vision tasks_](https://arxiv.org/abs/2311.06242),
  hosted on [Replicate](https://replicate.com/lucataco/florence-2-large)

- **Background removal** model: Carve,
  [_Tracer b7, finetuned on the CarveSet dataset_](https://huggingface.co/Carve/tracer_b7),
  hosted on [Replicate](https://replicate.com/lucataco/remove-bg)

## Licence

Except where otherwise indicated, all code in this repo is licensed under the
MIT licence.

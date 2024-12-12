# Setup

To run this installation you'll need:

- a computer which can run Chrome (inc. keyboard & mouse for setup purposes)
- a camera (e.g. a webcam)
- pens & paper for drawing
- a physical setup where the camera can see the "drawing area" (any flat surface
  where people can place their drawings in view of the camera)

Once everything is physically set up and plugged in, run the launch script:

```sh
IMGRES_AUTH=user:pass ./imgres-launch.sh
```

Then, draw things on the paper and put them in view of the camera. The AI (see
[below](#credits) for the exact list of models) will process the picture of your
sketch and provide a label, crop the image, process the sketch to provide a
"GenAI'd output, which will float across the screen.

If for some reason the launch script isn't working, you can do it manually:

- fire up Chrome to visit <https://imgres.fly.dev?capture> (or wherever you've
  hosted the web app part of the project), entering the username & password when
  prompted

- if you need to configure a "crop area" for the camera, you can provide the
  crop parameters (`x_offset,y_offset,width,height`) via the URL, e.g.

      https://imgres.fly.dev?capture_box=70,90,470,300

## Troubleshooting

### It says "processing..." but it's taking _ages_

If it hasn't run for a while, the inital AI pipeline (webcam capture->labelling
& cropping->GenAI output) might take a couple of minutes (the AI cloud provider
we're using, Replicate, uses a "cold start" approach where models that haven't
been used recently are booted out of memory and take a minute or so to be loaded
back in). Once it's up and running, the full pipeline should take about 5-10
seconds.

### I can see the Google Chrome top bar or the macOS dock on one of the monitors

If that's the case, someone has bumped the mouse to be over the top bar or dock.
You just need to move the mouse into the middle of one of the displays (the top
bar/dock should disappear) and then leave it---the mouse cursor will disappear
after a few seconds.

### The AI isn't doing anything

The app is configured to stop the processing pipeline if no change is detected
to the input image for the last little while. If that's the case, the
second-from-top-left image will be greyscale rather than colour. To kick-start
things, change what the camera sees by putting a different sketch under it (or
even moving the current sketch a little bit).

### It's not working, I just see a still image (of Helen Kellerman) on the macOS desktop

Grab the mouse and double-click the _Imaginative Restoration_ icon on the
desktop (right in the middle) and wait ~60s without touching the mouse, and it
should come back to life.

### The AI isn't doing a good job of processing my sketch

The AI pipeline can do some fun things to your input sketch, but (like all AI
tools) it can be hit-and-miss. If you're having trouble, try drawing something
big (filling the paper), simple and clear. But sometimes the "mistakes" are just
as fun/intresting as when it does what you expect it to.

## Customisation

While this code is primarily designed for the specific installation at
NIDA/NFSA/SOCY, it's open-source (yay) so you can see how it works, and even
modify it for your needs. You'll want to:

- change the video URL to point to your own audio & video files (look for
  `this.sound` and `this.video.src` in `assets/js/sketch_canvas_hook.js`)

- host it somewhere ([fly.io](https://fly.io) would be easy, because the config
  files are alreay here---you'd just need to create your own app and change the
  app name & other user credentials in the relevant places)

- in the running app server, set the `AUTH_USERNAME` and `AUTH_PASSWORD`
  environment variables to control access to the app, and add your own
  `REPLICATE_API_TOKEN` environment variable (so that the calls to the
  [Replicate](https://replicate.com)-hosted AI models will succeed)

- set up a camera (or other video source) to feed into the app

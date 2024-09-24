# Video frame files

This folder contains the video frames for the "input" videos, one folder per
video. The video file is in the folder as well.

As an example, the nggyu frames were obtained with the following command (make
sure to tweak the fps to match your source video):

```bash
ffmpeg -i nggyu.webm -t 30 -vf "crop=ih:ih,scale=512:512,fps=25" -vsync 0 frame-%04d.png
```

# spectrogram-ios

This project aims to implement an iOS app that displays an efficient high performance real time spectrogram from microphone inputs.

* Minimalist UI similar to the Android app Spectroid
* Sane defaults (logarithmic frequency axis, inferno colormap)
* Pause/resume
* Tapping on a slice of the spectrogram shows an intensity vs frequency plot at that time, with the peak frequency labelled, and tapping on that plot snaps to the nearest peak, showing the exact frequency of the peak

You may SSH into `pupmini.local` which is an M2 Mac Mini.
You can clone this repo into ~/projects/spectrogram-ios on the remote Mac Mini.
You may install XCode and run `brew` commands as needed to install dependencies and tools.
Take care to:

* avoid deleting any data on the Mac Mini (or on our local machine)
* avoid killing any existing running process on the Mac Mini or allow it to OOM (it only has 8GB of ram and it is running a Home Assistant VM), and likewise for the local machine.
* avoid using up excessive disk space

Alternatively, you may use GitHub Actions to perform macOS/iOS builds.

As this local Linux machine is vastly more powerful than the Mac Mini, you may wish to perform most of your implementation here.

You may git commit and push every time you make meaningful progress.

Don't modify this AGENTS.md.

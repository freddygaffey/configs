#!/bin/sh
# Hardware video decode. Without it a browser decodes video on the CPU at
# 10-20 W instead of 3-5 W on the iGPU — the biggest single battery lever when a
# browser is always open.
# Undo: sudo apt remove vainfo intel-media-va-driver-non-free
set -eu
sudo apt-get install -y vainfo intel-media-va-driver-non-free
echo
echo "verify:  vainfo | grep -E 'VAProfileH264High|VAProfileHEVCMain|VAProfileAV1'"
echo "firefox: media.ffmpeg.vaapi.enabled=true, then check about:support"
echo "chrome:  --enable-features=VaapiVideoDecoder, then check chrome://gpu"

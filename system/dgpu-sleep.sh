#!/bin/sh
# nvidia-persistenced keeps the driver initialised, which can hold the dGPU out
# of runtime suspend. The dGPU is ~12 W awake — about 40% of total draw on this
# machine. Only useful if you run headless CUDA, which nothing here does.
# Undo: sudo systemctl unmask --now nvidia-persistenced
set -eu
sudo systemctl mask --now nvidia-persistenced
echo "masked. check: cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status"

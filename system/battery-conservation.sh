#!/bin/sh
# Cap charge at ~60% (Lenovo conservation mode). Right for a machine that lives
# plugged in — calendar wear at 100% is what degrades the pack. Turn it OFF
# before taking the laptop anywhere, or you only get 60% capacity.
#   ./battery-conservation.sh on | off
set -eu
F=/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode
[ -e "$F" ] || { echo "no conservation_mode on this host"; exit 1; }
case "${1:-}" in
  on)  echo 1 | sudo tee "$F" >/dev/null; echo "ON — battery holds ~60%" ;;
  off) echo 0 | sudo tee "$F" >/dev/null; echo "OFF — charges to 100%" ;;
  *)   echo "current: $(cat "$F")  (1=on, 0=off)"; echo "usage: $0 on|off" ;;
esac

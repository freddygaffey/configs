# system/

Host-level setup for the Legion 5 16IRX9. **Not** run by any bootstrap script —
these write to `/etc`, mask systemd units, and are specific to one laptop.

One script per change, each short enough to read before running. Run the ones you
want; they're independent. Every script has its undo in the header comment.

| Script | What |
|---|---|
| `lid-behaviour.sh` | Lid shut: stays up on AC (reachable over ssh), suspends on battery. Applies at next boot — see the script for why it does not restart logind |
| `power-on-ac.sh` | udev rule: `performance` on AC, `power-saver` on battery (~5-8 W) |
| `dgpu-sleep.sh` | Mask `nvidia-persistenced` so the dGPU can runtime-suspend (~12 W) |
| `vaapi.sh` | Hardware video decode — a browser costs 10-20 W without it, 3-5 W with |
| `snap-retain.sh` | Cap snap revisions at 2; prints the commands to reclaim ~30-45 GB |
| `sudoers.sh` | Install the NOPASSWD allowlist (validated first) |
| `tracker-scope.sh` | Stop tracker indexing ~600 GB of archives and corpora |
| `battery-conservation.sh on\|off` | Cap charge at ~60% for an always-plugged host |

## sudoers

`sudoers.d/10-fred-ops` is a small NOPASSWD allowlist: `powerprofilesctl`,
`tailscale`, `dmesg`, `brightnessctl`, `lsof`, `dmidecode -t *`, and `rfcomm`
limited to `bind`/`release`/`show`/`connect` (for Bluetooth MAVLink).

`apt`, `systemctl`, `tee` and `turbostat` are deliberately absent — each is
equivalent to full passwordless root, so including them would make the allowlist
pointless. `turbostat -- <cmd>` runs `<cmd>` as root; `rfcomm listen`/`watch` do
the same, hence the subcommand limit. `dmidecode` is pinned to two arguments so
`--dump-bin <path>` can't be appended as an arbitrary root write.

Bluetooth MAVLink:

```sh
sudo rfcomm bind 0 <MAC> 1     # /dev/rfcomm0, root:dialout — you're in dialout
mavproxy.py --master=/dev/rfcomm0 --out=udpout:<mac-host>:14550
sudo rfcomm release 0
```

## Not done here

**Tailscale** — `sudo tailscale up --ssh` once, enable MagicDNS in the admin
console. One-time and interactive; a script adds nothing.

**RAPL counters** (`/sys/class/powercap/intel-rapl:*/energy_uj`) stay `0400 root`.
They're the only way to split draw into CPU vs iGPU, but were locked down over
CVE-2020-8694, where fine-grained energy readings leak enough to recover AES keys
from another process. When you need the detail, open it for the duration:

```sh
sudo chmod a+r /sys/class/powercap/intel-rapl:0/energy_uj
```

A reboot restores `0400`, which is the point.

# system/

Host-level configuration. **Not** run by any bootstrap script.

`bootstrap.sh` and `bootstrap-desktop.sh` only touch `$HOME` and install
packages, so they are safe to `curl | bash` onto any machine. Everything in this
directory writes to `/etc`, masks systemd units, or changes firmware-adjacent
settings, and is specific to one physical laptop. Running `legion.sh` on a server
would disable its suspend handling and add a udev rule for a battery it does not
have.

## legion.sh

Lenovo Legion 5 16IRX9 — i9-14900HX, RTX 4070 Mobile + Intel iGPU, 2560x1600
@165 Hz, 74.5 Wh battery on `BAT1`.

```sh
./system/legion.sh --dry-run   # print every change, make none
./system/legion.sh             # apply, after confirming
```

| Step | What | Why |
|---|---|---|
| 1 | Disable suspend | Reached over ssh; lid-close suspend makes it unreachable and it cannot wake over WiFi |
| 2 | udev AC/battery power profile | PPD doesn't switch on unplug; GNOME only does so at ~20% battery. Worth ~5-8 W |
| 3 | Mask `nvidia-persistenced` | Can hold the dGPU awake; the dGPU is ~12 W, about 40% of total draw |
| 4 | VA-API packages | Without hardware video decode a browser costs 10-20 W instead of 3-5 W |
| 5 | Cap snap retention at 2 | Old revisions had grown to ~65 GB |
| 6 | Battery conservation (opt-in) | Caps charge ~60%; reduces calendar wear on an always-plugged host |
| 7 | Reduce tracker scope | It was indexing ~600 GB of archives and corpora |
| 8 | Narrow NOPASSWD sudo allowlist | See [sudoers](#sudoers) below |
| 9 | RAPL counters readable by `adm` | Power measurement without root; deliberate trade-off, see below |

Each step is idempotent, skippable via `SKIP_<STEP>=1`, and its reversal is
documented in the comment above it in the script.

### Verify

```sh
systemctl is-enabled sleep.target                             # masked
cat /sys/firmware/acpi/platform_profile                       # performance on AC
cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status     # suspended
vainfo | grep VAProfileH264High                               # hardware decode
cat /sys/class/powercap/intel-rapl:0/energy_uj                 # readable, no sudo
awk '{print $1/1000000" W"}' /sys/class/power_supply/BAT1/power_now   # unplugged only
sudo -l | grep rfcomm                                         # bind/release/show/connect
sudo rfcomm listen 0 1 /bin/sh                                # must be REFUSED
```

Optional preferences (conservation mode, per-step skips) go in `local.env`
(gitignored); see `local.env.example`. Nothing secret lives in this repo.

Tailscale is deliberately **not** handled here — `sudo tailscale up --ssh` once,
enable MagicDNS in the admin console, done. Wrapping a one-time interactive
command in a script adds nothing.

## sudoers

`sudoers.d/10-fred-ops` is a deliberately tiny NOPASSWD allowlist. An allowlist
is only meaningful if every entry is *genuinely* limited, so `apt`, `systemctl`,
`tee`, `dd` and `turbostat` are all absent — each is equivalent to full
passwordless root (`turbostat -- <cmd>` runs `<cmd>` as root; package scripts run
arbitrary code; `tee` is an arbitrary root write).

The consequence is intentional: `legion.sh` still asks for a password once. That
prompt is the only thing between a compromised user session and permanent root.

Allowed: `powerprofilesctl`, `tailscale`, `dmesg`, `brightnessctl`, `lsof`,
`dmidecode -t *`, and `rfcomm` restricted to `bind` / `release` / `show` /
`connect`.

Two restrictions that matter:

- **`rfcomm` excludes `listen` and `watch`.** Both take a command argument and
  execute it as root on connection, so an unrestricted `rfcomm` entry would be
  full passwordless root wearing a Bluetooth costume.
- **`dmidecode` is pinned to two arguments** (`-t *`) so `--dump-bin <path>`, an
  arbitrary root file write, cannot be appended.

Install is always `visudo -cf` **before** the file reaches `/etc`, then
`install -m 0440 root:root`, then a full `visudo -c` with automatic rollback on
conflict. A malformed sudoers file locks you out of `sudo`; recovery is a root
shell or a live USB.

### Bluetooth MAVLink

What the `rfcomm` entries are for:

```sh
sudo rfcomm bind 0 <MAC> 1                              # /dev/rfcomm0, root:dialout
mavproxy.py --master=/dev/rfcomm0 --out=udpout:<mac-host>:14550
sudo rfcomm release 0
```

`fred` is in `dialout`, so MAVProxy itself needs no sudo — only the bind does.

### RAPL counters (step 9)

`/sys/class/powercap/intel-rapl:*/energy_uj` is the package energy counter — the
only way to split power draw into CPU vs iGPU vs rest, since
`BAT1/power_now` reports whole-system only. It ships `0400 root`; step 9 makes it
readable.

A udev rule rather than a `chmod` because sysfs nodes are recreated at boot with
default permissions — a manual chmod does not persist.

Locked to root originally over CVE-2020-8694. Single-user machine, deliberate
choice. `SKIP_RAPL=1` to leave it alone.

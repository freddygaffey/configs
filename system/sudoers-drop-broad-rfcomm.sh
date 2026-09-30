#!/bin/sh
# Remove any sudoers rule granting UNRESTRICTED /usr/bin/rfcomm.
#
# Why this is needed: sudoers rules only ever GRANT. The narrow rules in
# sudoers.d/10-fred-ops cannot override a broad one — only an explicit '!'
# negation can — so while a bare /usr/bin/rfcomm entry exists anywhere, the
# whitelist is decorative. And an unrestricted rfcomm is a passwordless root
# shell, because `rfcomm listen` and `rfcomm watch` take a command and run it as
# root on connection.
#
#   ./sudoers-drop-broad-rfcomm.sh            show what would change
#   ./sudoers-drop-broad-rfcomm.sh --go       apply it
#
# Every file is validated with `visudo -cf` BEFORE it replaces the original, and
# swapped in with install(1) so the replacement is atomic — a half-written
# sudoers file locks you out of sudo entirely.
set -eu
GO=0
[ "${1:-}" = "--go" ] && GO=1

# A line that mentions /usr/bin/rfcomm NOT followed by an argument pattern, i.e.
# it ends there or the next thing is a comma introducing another command.
BROAD='/usr/bin/rfcomm[[:space:]]*\(,\|$\)'

found=0
for f in /etc/sudoers /etc/sudoers.d/*; do
    [ -f "$f" ] || continue
    sudo grep -q "$BROAD" "$f" 2>/dev/null || continue
    found=1
    echo "=== $f"
    sudo grep -n "$BROAD" "$f" | sed 's/^/    removing: /'

    tmp=$(mktemp)
    sudo grep -v "$BROAD" "$f" > "$tmp"

    if [ ! -s "$tmp" ]; then
        echo "    (file would be empty — delete it instead: sudo rm $f)"
        rm -f "$tmp"; continue
    fi
    if ! visudo -cf "$tmp" >/dev/null 2>&1; then
        echo "    REFUSED: the result does not parse, leaving $f alone" >&2
        visudo -cf "$tmp" 2>&1 | sed 's/^/      /' >&2
        rm -f "$tmp"; continue
    fi

    if [ "$GO" = 1 ]; then
        sudo install -o root -g root -m 0440 "$tmp" "$f"
        echo "    replaced (validated, atomic)"
    else
        echo "    would replace (validated)"
    fi
    rm -f "$tmp"
done

[ "$found" = 1 ] || { echo "No unrestricted /usr/bin/rfcomm rule found."; exit 0; }

if [ "$GO" = 1 ]; then
    sudo visudo -c >/dev/null && echo "sudoers tree valid."
    echo
    echo "Now verify the whitelist actually holds:"
    echo "  sudo -l | grep rfcomm            # only bind/release/show shapes"
    echo "  sudo rfcomm listen 0 1 /bin/sh   # must say 'not allowed'"
    echo "NB 'Can't bind RFCOMM socket' means it RAN — that is still permitted."
else
    echo
    echo "Dry run. Re-run with --go to apply."
fi

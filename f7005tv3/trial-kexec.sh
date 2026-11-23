#!/bin/sh
set -eu
umask 077
D=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$D"
ACTION=${1:---load}
STATE=/tmp/f7005tv3-kexec-state
LOCK=$STATE.lock
mkdir "$LOCK" || { echo 'Another trial operation is active'; exit 1; }
trap 'rm -rf "$LOCK"' EXIT
die() { echo "$*" >&2; exit 1; }
command -v sha256sum >/dev/null || die 'sha256sum required'
[ -s sha256sums-trial ] || die 'missing checksum manifest'
expected='trial-Image.gz trial-dtb.bin trial-kexec.sh trial-kx.tgz stock-evidence.sh'
if [ -e trial-initrd ]; then expected="$expected trial-initrd"; fi
printf '%s\n' $expected | sort > "$LOCK/expected"
awk 'NF != 2 || length($1) != 64 || $1 ~ /[^0-9a-f]/ {exit 1} {print $2}' sha256sums-trial > "$LOCK/names" || die 'invalid checksum manifest'
sort "$LOCK/names" > "$LOCK/list"
cmp "$LOCK/expected" "$LOCK/list" || die 'unexpected checksum entries'
sha256sum -c sha256sums-trial || die 'trial checksum mismatch'
tar xzf trial-kx.tgz -C "$LOCK"
KX=$LOCK/kexec
export LD_LIBRARY_PATH=$LOCK/lib
boot=$(cat /proc/sys/kernel/random/boot_id)
digest=$(sha256sum sha256sums-trial)
loaded=/sys/kernel/kexec_loaded
case "$ACTION" in
 --load)
   rm -f "$STATE"
   gzip -dc trial-Image.gz > "$LOCK/Image"
   set --
   if [ -f trial-initrd ]; then set -- "--initrd=$D/trial-initrd"; fi
   "$KX" --load --mem-min=0x88000000 --mem-max=0x9b000000 "$LOCK/Image" --dtb="$D/trial-dtb.bin" "$@" --command-line='root=/dev/ram0 rw console=ttyAMA0,115200n8 loglevel=7 panic=20'
   printf '%s\n' "$boot $digest" > "$LOCK/state"
   mv "$LOCK/state" "$STATE"
   ;;
 --exec)
   [ "$(cat "$STATE")" = "$boot $digest" ] || die 'load this kit first'
   if [ -r "$loaded" ]; then [ "$(cat "$loaded")" = 1 ] || die 'no loaded kernel'; fi
   "$KX" --exec
   ;;
 --unload) "$KX" --unload; rm -f "$STATE" ;;
 *) die 'use --load, --exec or --unload' ;;
esac

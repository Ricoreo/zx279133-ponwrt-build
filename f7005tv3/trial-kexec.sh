#!/bin/sh
# Load or execute the F7005TV3 OpenWrt initramfs through the running kernel.
# This script never writes NAND. Run --load first; after it succeeds, run --exec.
set -eu

D=${D:-$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)}
KX="$D/kexec"
ACTION=${1:---load}
MEMARGS="--mem-min=0x88000000 --mem-max=0x9b000000"
CMDLINE=${CMDLINE:-'root=/dev/ram0 rw console=ttyAMA0,115200n8 loglevel=7 panic=20'}

say() { echo "f7005tv3-ram: $*"; }
die() { echo "f7005tv3-ram: $*" >&2; exit 1; }

if [ ! -x "$KX" ] && [ -s "$D/trial-kx.tgz" ]; then
	tar -xzf "$D/trial-kx.tgz" -C "$D" || die 'kexec support archive extraction failed'
fi
[ -x "$KX" ] || chmod +x "$KX" 2>/dev/null || :
[ -x "$KX" ] || die "missing bundled kexec executable: $KX"
[ -d "$D/lib" ] && export LD_LIBRARY_PATH="$D/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

case "$ACTION" in
	--load)
		[ -s "$D/trial-Image.gz" ] || die 'missing trial-Image.gz'
		[ -s "$D/trial-dtb.bin" ] || die 'missing trial-dtb.bin'
		if [ -s "$D/sha256sums-trial" ] && command -v sha256sum >/dev/null 2>&1; then
			(cd "$D" && sha256sum -c sha256sums-trial) || die 'trial file checksum failed'
		fi
		"$KX" --version >/dev/null 2>&1 || die 'bundled kexec cannot run on this firmware'
		gzip -dc "$D/trial-Image.gz" > "$D/trial-Image" || die 'Image decompression failed'
		say 'loading RAM image; no NAND partitions are included in its device tree'
		"$KX" --load $MEMARGS "$D/trial-Image" --dtb="$D/trial-dtb.bin" \
			--command-line="$CMDLINE" || die 'kexec --load failed; current system is still running'
		say 'image loaded but not started. Check that the current web interface still responds.'
		say 'If ready, run: sh trial-kexec.sh --exec'
		;;
	--exec)
		say 'starting the loaded RAM image in 5 seconds. Power-cycling returns to NAND firmware.'
		sleep 5
		"$KX" --exec || die 'kexec --exec failed'
		;;
	--unload)
		"$KX" --unload || die 'could not unload the pending kexec image'
		say 'pending RAM image unloaded'
		;;
	*) die 'usage: sh trial-kexec.sh [--load|--exec|--unload]' ;;
esac

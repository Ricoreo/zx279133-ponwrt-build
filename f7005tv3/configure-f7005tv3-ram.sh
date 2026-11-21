#!/bin/sh
# Configure the reference kernel and ImmortalWrt build for a RAM-only F7005TV3 trial.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
IW_DIR=${1:?OpenWrt source directory required}
KERNEL_TREE=${2:?external kernel source directory required}
DTS=zx279133-f7005tv3

[ -f "$KERNEL_TREE/Makefile" ] || { echo "invalid kernel tree: $KERNEL_TREE" >&2; exit 1; }
[ -f "$KERNEL_TREE/arch/arm64/boot/dts/zte/$DTS.dts" ] || {
	echo "missing F7005TV3 DTS: $KERNEL_TREE/arch/arm64/boot/dts/zte/$DTS.dts" >&2; exit 1;
}
grep -qx "dtb-y += $DTS.dtb" "$KERNEL_TREE/arch/arm64/boot/dts/zte/Makefile" || {
	echo "F7005TV3 DTB is not selected by the ZTE DTS Makefile" >&2; exit 1;
}

# Reuse the reference's reviewed ZX279133 kernel and initramfs package selections.
# Its profile is used only to resolve the build; the image recipe is retargeted below.
sh "$ROOT/scripts/configure-sk-d840n.sh" "$IW_DIR" "$KERNEL_TREE" initramfs

IMAGE_MK="$IW_DIR/target/linux/zte/image/Makefile"
python3 - "$IMAGE_MK" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
s = p.read_text()
start = s.index('define Device/skyworth_sk-d840n')
end = s.index('endef', start)
block = s[start:end]
old = 'DEVICE_DTS := zx279133-sk-d840n'
if old not in block:
    raise SystemExit('SK image profile did not contain its expected DTS selector')
block = block.replace(old, 'DEVICE_DTS := zx279133-f7005tv3', 1)
p.write_text(s[:start] + block + s[end:])
PY

# The reference flash profile forces a JFFS2 MTD root. A kexec initramfs must accept
# the command line passed by kexec instead. The stock device tree also has no flash
# partitions in this RAM trial, so no MTD root is available or needed.
for f in "$IW_DIR"/target/linux/zte/config-* "$IW_DIR"/target/linux/zte/zx279133/config-*; do
	[ -f "$f" ] || continue
	if grep -q '^CONFIG_CMDLINE_FORCE=y$' "$f"; then
		sed -i 's/^CONFIG_CMDLINE_FORCE=y$/# CONFIG_CMDLINE_FORCE is not set/' "$f"
	fi
	if grep -q '^CONFIG_CMDLINE_EXTEND=y$' "$f"; then
		sed -i 's/^CONFIG_CMDLINE_EXTEND=y$/# CONFIG_CMDLINE_EXTEND is not set/' "$f"
	fi
done

# The reference recovery image includes a flash utility. This trial deliberately does not.
cd "$IW_DIR"
sed -i '/^CONFIG_PACKAGE_zrec=y$/d; /^# CONFIG_PACKAGE_zrec is not set$/d' .config
printf '# CONFIG_PACKAGE_zrec is not set\n' >> .config
make defconfig

grep -qx 'CONFIG_TARGET_ROOTFS_INITRAMFS=y' .config || {
	echo 'RAM initramfs image was not selected' >&2; exit 1;
}
grep -qx 'CONFIG_TARGET_zte_zx279133_DEVICE_skyworth_sk-d840n=y' .config || {
	echo 'reference ZX279133 build profile was not selected' >&2; exit 1;
}
if grep -q '^CONFIG_PACKAGE_zrec=y$' .config; then
	echo 'flash utility zrec unexpectedly remains in the RAM trial image' >&2; exit 1
fi
grep -q 'DEVICE_DTS := zx279133-f7005tv3' "$IMAGE_MK" || {
	echo 'F7005TV3 DTB is not selected for the initramfs image' >&2; exit 1;
}

echo 'F7005TV3 RAM-only initramfs configuration is ready.'

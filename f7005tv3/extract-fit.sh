#!/bin/bash
set -euo pipefail
fit=$1
out=$2
cfg=/configurations/$(fdtget -t s "$fit" /configurations default)
mapfile -t nodes < <(fdtget -l "$fit" /images)
extract() {
  local name index
  name=$(fdtget -t s "$fit" "$cfg" "$1")
  for index in "${!nodes[@]}"; do
    if [[ ${nodes[index]} == "$name" ]]; then
      dumpimage -T flat_dt -p "$index" -o "$2.packed" "$fit"
      case $(fdtget -t s "$fit" "/images/$name" compression) in
        none) cat "$2.packed" ;;
        gzip) gzip -dc "$2.packed" ;;
        lzma|xz) xz -dc "$2.packed" ;;
        zstd) zstd -dc "$2.packed" ;;
        *) return 1 ;;
      esac > "$2"
      rm "$2.packed"
      return 0
    fi
  done
  return 1
}
extract kernel "$out/kernel"
extract fdt "$out/trial-dtb.bin"
[[ $(fdtget "$out/trial-dtb.bin" / compatible) == "zte,f7005tv3 zte,zx279133" ]]
payload=$out/kernel
if fdtget "$fit" "$cfg" ramdisk >/dev/null 2>&1; then
  extract ramdisk "$out/trial-initrd"
  payload=$out/trial-initrd
fi
python3 f7005tv3/check-initramfs.py "$payload"
gzip -9nc "$out/kernel" > "$out/trial-Image.gz"
rm "$out/kernel"

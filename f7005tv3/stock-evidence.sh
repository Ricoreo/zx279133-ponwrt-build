#!/bin/sh
# Run on stock Linux. No writes, no /chosen properties or device identifiers.
printf '%s\n' '[System RAM and reservations]'
awk '/System RAM|reserved/ {print}' /proc/iomem
for dir in /proc/device-tree/reserved-memory/*; do
  [ -f "$dir/reg" ] || continue
  printf '%s ' "${dir##*/}"; od -An -tx1 "$dir/reg"
done
printf '%s\n' '[network links: repeat with one labelled jack connected at a time]'
for dev in /sys/class/net/*; do
  printf '%s ' "${dev##*/}"
  cat "$dev/carrier" 2>/dev/null || echo unknown
done

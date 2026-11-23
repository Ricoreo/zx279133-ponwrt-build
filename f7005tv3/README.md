# ZTE F7005TV3 RAM-only OpenWrt trial

This branch builds a **RAM-only** initramfs candidate for the F7005TV3. The image is loaded with the running Linux kernel's `kexec_load` interface. It does not include a flash image, a partition table for the F7005TV3, or a flash-writing script. Power-cycling returns the device to the firmware stored in NAND.

The device-specific facts in the board file come from the live FDT supplied for this F7005TV3: ZTE 133 / ZX279133, two Cortex-A53 cores, 512 MiB RAM, PL011-compatible console, and the addresses of its SoC nodes. The enabled NPPT, SerDes, 9132 switch-port map, memory carve-outs, and external PHY wiring are provisional adaptations from another ZX279133 board. A successful build proves that the toolchain accepts the DTS and compiles the kernel; it does not prove that the F7005TV3 Ethernet or PON paths work.

The reference board reports that the vendor kernel's armed watchdog can reset the device tens of seconds after a kexec jump. This trial does not modify the watchdog reset register; treat the first boot as a short observation window. A watchdog reset should return to the NAND firmware, but this behavior has not been confirmed on the F7005TV3.

The trial image disables the SPI flash controller and contains no `zrec` flasher. It uses a static LAN address of `192.168.1.2`, disables DHCP service, and provides a plain HTTP status file at `/f7005tv3-ram-trial.txt`. It does not set up PON WAN service.

## Build output

The GitHub Actions workflow uploads two files as a 30-day artifact:

- `f7005tv3-initramfs.itb`: FIT initramfs for reference and inspection.
- `f7005tv3-ram-trial.tgz`: raw ARM64 kernel image, F7005TV3 DTB, checksum manifest, trial script, and the kexec runtime package.

The workflow does not publish a Release and does not build a flashable image.

## Trial procedure

Download the artifact on the Mac, place `f7005tv3-ram-trial.tgz` in a directory, and serve that directory over HTTP on the same LAN, for example with `python3 -m http.server 8080`. From the device's root shell, download and unpack it:

```sh
wget -O /tmp/f7005tv3-ram-trial.tgz http://<Mac-LAN-IP>:8080/f7005tv3-ram-trial.tgz
mkdir -p /tmp/f7005tv3-trial
tar -xzf /tmp/f7005tv3-ram-trial.tgz -C /tmp/f7005tv3-trial
cd /tmp/f7005tv3-trial
sh trial-kexec.sh --load
```

The load step checks the kexec executable and image checksums before it stages the next kernel. If it succeeds and the current system still responds, start it with:

```sh
sh trial-kexec.sh --exec
```

After boot, check `http://192.168.1.2/f7005tv3-ram-trial.txt` promptly. If the page does not respond, let the watchdog reset the board or power-cycle it to return to its NAND firmware. The watchdog-reset recovery path itself is not yet verified on the F7005TV3. Do not run a flash command with this image.

## Current limits

- The F7005TV3 network path has not been confirmed against the reference board's mainline driver. Management access after kexec may fail; the RAM trial remains reversible by power-cycling.
- The image is not tested on the physical F7005TV3 until the owner runs the trial.
- The stock firmware's live device tree contains a vendor key in `/chosen`; it was intentionally excluded from this repository.

## Collect stock-board evidence

Run `sh stock-evidence.sh` on the original firmware. Record one snapshot per labelled jack with a single cable attached. Carrier data may show only the CPU-facing interface; if it does, record that ambiguity rather than assigning switch ports. Compare the reservation addresses with the board DTS before enabling provisional DMA regions. No raw /chosen data is needed. Compare the downloaded archive digest against the Actions checksum before unpacking. The load receipt binds this script's last successful load to the current boot and manifest; another program can still replace the kernel in between. Use a fresh trial directory for each build.

# Nintendo Switch boot files

The `profile_switch` ARM64 profile builds `LiberNT.img` as a Nintendo Switch
(Tegra X1) microSD card: an MBR disk with a FAT32 boot partition
(`LIBERNTBOOT`, type 0x0c) followed by the NTFS system partition.

## Boot chain

1. Hekate starts. A modchip loads `payload.bin` from the root of the card
   (Mariko units: V2, Lite and OLED); an unpatched V1 injects it over RCM.
2. Hekate reads `bootloader/hekate_ipl.ini` and boots its `[LiberNT]` entry
   after three seconds. Hold VOL- while it starts to stay in its menu.
3. The entry uses the L4T Loader (`l4t=1`), which starts
   `switchroot/winx/bl31.bin` (Arm Trusted Firmware) and then
   `switchroot/winx/bl33.bin` (the WinX EDK II UEFI firmware).
4. The UEFI firmware starts `EFI/BOOT/bootaa64.efi`, the LiberNT boot manager,
   which loads LiberNT from the NTFS partition.

## Preparing the boot files

Hekate, BL31 and BL33 are third-party binaries and are not in the tree. Run
`scripts/prepare_switch_boot.sh` (Linux, WSL, macOS) or
`scripts\prepare_switch_boot.cmd` (Windows) once. It downloads them into
`downloads/`, checks each against a pinned SHA-256 and lays them out in
`optional/` exactly as they appear on the card. Git ignores both folders.

The image build copies everything under `optional/` to the boot partition,
keeping its paths, and then adds `hekate_ipl.ini` from this folder. Without
`optional/`, configuration warns and `LiberNT.img` is built but does not boot.
After running the script, rebuild `liberntimg`; the build notices the new files
on its own.

| Card path | Source | License |
|---|---|---|
| `payload.bin`, `bootloader/update.bin`, `bootloader/sys`, `bootloader/res` | [hekate](https://github.com/CTCaer/hekate) v6.5.4 | GPL-2.0 |
| `switchroot/winx/bl33.bin` | [WinX](https://github.com/steck0714/winx) release 2 | GPL-2.0 |
| `switchroot/winx/bl31.bin` | Switchroot ATF, from the Lakka 5.0 Switch package | BSD-3-Clause |
| `bootloader/hekate_ipl.ini` | this folder | GPL-3.0-or-later |
| `EFI/BOOT/bootaa64.efi`, `EFI/LiberNT/Boot/*` | build output | GPL-3.0-or-later |

The versions, URLs and hashes are at the top of both scripts; change them in
both together. The script fetches only the last 18 MiB of the 1.2 GiB Lakka
archive, which holds its boot files.

Hekate and WinX are GPL-2.0. If you hand out a prepared `LiberNT.img`, you must
also offer their corresponding source: hekate tag `v6.5.4`, and WinX commit
`9eba951` with `edk2-stable202402` as listed in its `NOTICE.winx.md`.

## Hardware status

- The WinX author has tested it on one Erista (V1) console. Mariko consoles
  (V2, Lite, OLED) have not been tested.
- WinX reads the microSD card but does not write to it.
- Its ACPI tables describe the CPUs, the GIC, the timer, UART-B (DBG2, the
  right Joy-Con rail) and SDMMC1/SDMMC4 as `PNP0D40`, which `sdbus` binds.
- LiberNT has no Tegra display, USB or input drivers yet. The display is the
  UEFI framebuffer, in the panel's native portrait orientation.
- For a serial log on the right Joy-Con rail, add `uart_port=2` to the
  `[LiberNT]` entry. That setting has not been tested with WinX.

## Building

```
scripts/prepare_switch_boot.sh
configure.sh -a arm64 -DROSCONFIG_PROFILE=profile_switch
ninja liberntimg
```

Write `LiberNT.img` to the microSD card.

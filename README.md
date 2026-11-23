# rawaru

The graphical installer for [Fiordland Linux](https://fiordland.apollo44.lat), built with PySide6 and QML.

- Pick from 11 desktops and 13 window managers, with optional dotfiles
- Btrfs with snapper snapshots you can boot from the GRUB menu (grub-btrfs), zram swap
- Whole disk, or alongside Windows: shrinks NTFS or uses free space (UEFI + GPT)
- GRUB on UEFI and BIOS, with os-prober
- GPU driver detection, CachyOS or Arch kernel
- VM guest tools installed automatically

The GUI runs as the live user and drives `engine.py` as root through `sudo -n`, passing a temporary JSON config. Disk detection for dual boot lives in `disks.py` (`engine.py --probe DISK` prints it as JSON). The engine reports progress as JSON lines.

## Run

```
python3 rawaru.py            # real install, live ISO only
python3 rawaru.py --dry-run  # walk through without touching disks
```

Needs `python`, `pyside6`, `qt6-wayland`, `arch-install-scripts`, `gptfdisk`, `btrfs-progs`, `dosfstools`, `parted`, `psmisc`.

## License

GPL-3.0. See [LICENSE](LICENSE).

# rawaru

The graphical installer for [Fiordland Linux](https://fiordland.apollo44.lat), built with PySide6 and QML.

- Pick from 11 desktops and 13 window managers, with optional dotfiles
- Btrfs with snapper snapshots, zram swap
- systemd-boot (UEFI) or GRUB (BIOS)
- GPU driver detection, CachyOS or Arch kernel
- VM guest tools installed automatically

The GUI runs as the live user and drives `engine.py` as root through `sudo -n`, passing a temporary JSON config. The engine reports progress as JSON lines.

## Run

```
python3 rawaru.py            # real install, live ISO only
python3 rawaru.py --dry-run  # walk through without touching disks
```

Needs `python`, `pyside6`, `qt6-wayland`, `arch-install-scripts`, `gptfdisk`, `btrfs-progs`, `dosfstools`, `parted`, `psmisc`.

## License

GPL-3.0. See [LICENSE](LICENSE).

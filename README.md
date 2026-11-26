# rawaru

<p><a href="https://donate.stripe.com/8x25kFfe96fn0WL6X12wU00"><img src=".github/donate.svg" alt="Donate to Fiordland"></a> <a href="https://discord.gg/gy4ANH2Q9V"><img src=".github/discord.svg" alt="Join the Fiordland Discord"></a></p>

Created by [Apollo](https://apollo44.lat) ([3cfl](https://github.com/3cfl) on GitHub, u5sk on Discord), as part of [Fiordland Linux](https://github.com/Fiordland-Linux/fiordland).

The graphical installer for [Fiordland Linux](https://fiordlandlinux.org), built with PySide6 and QML.

- Pick from 11 desktops and 13 window managers, with optional dotfiles
- Btrfs with snapper snapshots you can boot from the GRUB menu (grub-btrfs), zram swap
- Whole disk, alongside Windows (shrinks NTFS or uses free space, UEFI + GPT), or partitions you pick, with KDE Partition Manager one click away
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

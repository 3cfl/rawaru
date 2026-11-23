#!/usr/bin/env python3
import glob
import json
import os
import re
import subprocess
import sys
import tempfile
import time

MNT = "/mnt"
LOCAL_REPO = "/opt/fiordland/repo"

PACKAGES = [
    "base", "linux", "linux-firmware", "btrfs-progs", "dosfstools", "networkmanager", "sudo", "nano",
    "hyprland", "xdg-desktop-portal-hyprland", "xdg-desktop-portal-gtk", "kitty", "crest", "quickshell",
    "upower", "libnotify", "pipewire", "pipewire-pulse", "pipewire-alsa", "wireplumber",
    "greetd", "greetd-tuigreet", "noto-fonts", "noto-fonts-emoji", "inter-font", "ttf-jetbrains-mono",
    "ttf-material-symbols-variable", "firefox", "thunar", "gvfs", "pavucontrol",
    "bluez", "bluez-utils", "brightnessctl", "flatpak", "tawaki", "fiordland-desktop", "fastfetch", "git",
    "base-devel", "zram-generator", "man-db", "qt6-wayland", "xdg-user-dirs", "wl-clipboard", "grim",
    "slurp", "playerctl", "papirus-icon-theme", "snapper", "snap-pac", "pacman-contrib", "power-profiles-daemon",
    "sof-firmware", "alsa-firmware", "reflector",
]

SERVICES = [
    "NetworkManager", "bluetooth", "greetd", "systemd-timesyncd", "fstrim.timer",
    "power-profiles-daemon", "snapper-timeline.timer", "snapper-cleanup.timer", "reflector.timer",
    "tawaki-catalogue.timer",
]

SUBVOLS = [("@", ""), ("@home", "home"), ("@log", "var/log"), ("@pkg", "var/cache/pacman/pkg"), ("@snapshots", ".snapshots")]
MOUNT_OPTS = "noatime,compress=zstd:1"
FIORD_REPO = "[fiordland]\nSigLevel = Optional TrustAll\nServer = https://fiordland.apollo44.lat/repo/$arch\n\n"

DRY = False


def emit(**kw):
    sys.stdout.write(json.dumps(kw) + "\n")
    sys.stdout.flush()


def log(msg):
    emit(log=msg)


def status(msg, progress=None):
    if progress is None:
        emit(status=msg)
    else:
        emit(status=msg, progress=round(progress, 4))


def run(cmd, inp=None, check=True):
    log("$ " + " ".join(cmd))
    if DRY:
        time.sleep(0.05)
        return ""
    p = subprocess.run(cmd, input=inp, capture_output=True, text=True)
    for line in (p.stdout + p.stderr).splitlines():
        if line.strip():
            log(line)
    if check and p.returncode != 0:
        raise RuntimeError(f"{cmd[0]} failed ({p.returncode})")
    return p.stdout


def chroot(*cmd, inp=None, check=True):
    return run(["arch-chroot", MNT, *cmd], inp=inp, check=check)


def write(path, text, mode=0o644):
    full = MNT + path
    log(f"write {path}")
    if DRY:
        return
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w") as f:
        f.write(text)
    os.chmod(full, mode)


def part_name(disk, n):
    return f"{disk}p{n}" if re.search(r"\d$", disk) else f"{disk}{n}"


def is_uefi():
    return os.path.isdir("/sys/firmware/efi")


def cpu_vendor():
    try:
        with open("/proc/cpuinfo") as f:
            text = f.read()
    except OSError:
        return ""
    if "GenuineIntel" in text:
        return "intel"
    if "AuthenticAMD" in text:
        return "amd"
    return ""


def virt():
    try:
        return subprocess.run(["systemd-detect-virt", "--vm"], capture_output=True, text=True).stdout.strip()
    except Exception:
        return ""


def gpus():
    found = []
    for d in glob.glob("/sys/bus/pci/devices/*"):
        try:
            with open(f"{d}/class") as f:
                if not f.read().startswith("0x03"):
                    continue
            with open(f"{d}/vendor") as f:
                vendor = f.read().strip()
            with open(f"{d}/device") as f:
                device = int(f.read().strip(), 16)
        except (OSError, ValueError):
            continue
        found.append((vendor, device))
    return found


def gpu_setup(found):
    g = {"pkgs": ["mesa", "lib32-mesa", "vulkan-icd-loader", "lib32-vulkan-icd-loader"],
         "services": [], "modules": [], "params": [], "nvidia": False}
    vendors = {v for v, _ in found}
    if "0x8086" in vendors:
        g["pkgs"] += ["vulkan-intel", "lib32-vulkan-intel", "intel-media-driver"]
    if "0x1002" in vendors:
        g["pkgs"] += ["vulkan-radeon", "lib32-vulkan-radeon"]
    nv = [dev for v, dev in found if v == "0x10de"]
    if nv and max(nv) >= 0x1e00:
        g["nvidia"] = True
        g["pkgs"] += ["nvidia-open", "nvidia-utils", "lib32-nvidia-utils", "nvidia-settings",
                      "egl-wayland", "libva-nvidia-driver"]
        g["services"] += ["nvidia-suspend", "nvidia-hibernate", "nvidia-resume"]
        g["modules"] += ["nvidia", "nvidia_modeset", "nvidia_uvm", "nvidia_drm"]
        g["params"] += ["nvidia_drm.modeset=1", "nvidia_drm.fbdev=1"]
    elif nv:
        g["pkgs"] += ["vulkan-nouveau", "lib32-vulkan-nouveau"]
    return g


GPU = gpu_setup([])


def guest_tools():
    v = virt()
    if v in ("kvm", "qemu"):
        return ["qemu-guest-agent", "spice-vdagent"], ["qemu-guest-agent"]
    if v == "oracle":
        return ["virtualbox-guest-utils"], ["vboxservice"]
    if v == "vmware":
        return ["open-vm-tools"], ["vmtoolsd"]
    return [], []


def partition(cfg):
    disk = cfg["disk"]
    uefi = is_uefi()
    status("Preparing your disk", 0.01)
    run(["swapoff", "-a"], check=False)
    run(["umount", "-R", MNT], check=False)
    for line in (run(["lsblk", "-lnpo", "NAME", disk], check=False) or "").split()[1:]:
        run(["umount", line], check=False)
    run(["wipefs", "-af", disk])
    run(["sgdisk", "--zap-all", disk])
    if uefi:
        run(["sgdisk", "-n1:0:+1G", "-t1:ef00", "-c1:EFI", "-n2:0:0", "-t2:8304", "-c2:Fiordland", disk])
    else:
        run(["sgdisk", "-n1:0:+1M", "-t1:ef02", "-c1:BIOS", "-n2:0:0", "-t2:8304", "-c2:Fiordland", disk])
    run(["partprobe", disk], check=False)
    run(["udevadm", "settle"], check=False)
    boot, root = part_name(disk, 1), part_name(disk, 2)
    status("Formatting", 0.03)
    if uefi:
        run(["mkfs.fat", "-F32", "-n", "EFI", boot])
    run(["mkfs.btrfs", "-f", "-L", "fiordland", root])
    run(["mount", root, MNT])
    for name, _ in SUBVOLS:
        run(["btrfs", "subvolume", "create", f"{MNT}/{name}"])
    run(["umount", MNT])
    for name, path in SUBVOLS:
        target = os.path.join(MNT, path) if path else MNT
        if not DRY:
            os.makedirs(target, exist_ok=True)
        run(["mount", "-o", f"{MOUNT_OPTS},subvol={name}", root, target])
    if uefi:
        if not DRY:
            os.makedirs(f"{MNT}/boot", exist_ok=True)
        run(["mount", "-o", "umask=0077", boot, f"{MNT}/boot"])
    return root, uefi


def pacman_conf():
    with open("/etc/pacman.conf") as f:
        base = f.read()
    base = re.sub(r"(?ms)^\[fiordland\].*?(?=^\[|\Z)", "", base)
    repo = f"[fiordland]\nSigLevel = Optional TrustAll\nServer = file://{LOCAL_REPO}\n\n"
    base = base.replace("[core]", repo + "[core]", 1)
    base = re.sub(r"(?m)^#?ParallelDownloads.*$", "ParallelDownloads = 10", base)
    base = re.sub(r"(?m)^#\[multilib\]\n#Include", "[multilib]\nInclude", base)
    fd, path = tempfile.mkstemp(prefix="rawaru-pacman-", suffix=".conf")
    with os.fdopen(fd, "w") as f:
        f.write(base)
    return path


def pacstrap(pkgs):
    status("Downloading packages", 0.05)
    if DRY:
        total = len(pkgs)
        for i, p in enumerate(pkgs):
            time.sleep(0.04)
            status(f"Downloading {p}", 0.08 + 0.37 * (i + 1) / total)
        for i, p in enumerate(pkgs):
            time.sleep(0.04)
            status(f"Installing {p}", 0.45 + 0.37 * (i + 1) / total)
        return
    status("Finding the fastest mirrors", 0.05)
    run(["timeout", "50", "systemctl", "start", "fiordland-mirrors.service"], check=False)
    status("Downloading packages", 0.06)
    conf = pacman_conf()
    cmd = ["pacstrap", "-K", "-C", conf, MNT, *pkgs, "--noconfirm", "--needed"]
    log("$ " + " ".join(cmd))
    env = dict(os.environ, LC_ALL="C")
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env, bufsize=1)
    total = None
    dl = inst = 0
    re_total = re.compile(r"^Packages \((\d+)\)")
    re_inst = re.compile(r"^\(\s*(\d+)/(\d+)\) installing (\S+)")
    for raw in p.stdout:
        line = raw.rstrip()
        if not line:
            continue
        log(line)
        m = re_total.match(line)
        if m:
            total = int(m.group(1))
            continue
        m = re_inst.match(line)
        if m:
            inst, total = int(m.group(1)), int(m.group(2))
            status(f"Installing {m.group(3)}", 0.45 + 0.37 * inst / total)
            continue
        s = line.strip()
        if total and s.endswith("downloading...") and inst == 0:
            dl += 1
            name = s.split()[0]
            status(f"Downloading {name}", 0.08 + 0.37 * min(dl, total) / total)
    p.wait()
    os.unlink(conf)
    if p.returncode != 0:
        raise RuntimeError("pacstrap failed")


def configure(cfg, root, uefi):
    status("Configuring your system", 0.83)
    if not DRY:
        fstab = subprocess.run(["genfstab", "-U", MNT], capture_output=True, text=True, check=True).stdout
        fstab = re.sub(r",subvolid=\d+", "", fstab)
        with open(f"{MNT}/etc/fstab", "a") as f:
            f.write(fstab)
    log("genfstab -U /mnt")
    chroot("sed", "-i", "-e", "s/^#Color/Color/", "-e", "s/^#\\?ParallelDownloads.*/ParallelDownloads = 10/",
           "/etc/pacman.conf")
    if not DRY:
        with open(f"{MNT}/etc/pacman.conf") as f:
            pc = f.read()
        pc = re.sub(r"(?m)^#\[multilib\]\n#Include", "[multilib]\nInclude", pc)
        if "[fiordland]" not in pc:
            pc = pc.replace("[core]", FIORD_REPO + "[core]", 1)
            with open(f"{MNT}/etc/pacman.conf", "w") as f:
                f.write(pc)
    log("added [fiordland] repo")
    tz = cfg.get("timezone") or "UTC"
    chroot("ln", "-sf", f"/usr/share/zoneinfo/{tz}", "/etc/localtime")
    chroot("hwclock", "--systohc", check=False)
    locale = cfg.get("locale") or "en_US.UTF-8"
    gen = {locale, "en_US.UTF-8"}
    write("/etc/locale.gen", "".join(f"{l} UTF-8\n" for l in sorted(gen)))
    chroot("locale-gen")
    write("/etc/locale.conf", f"LANG={locale}\n")
    keymap = cfg.get("keymap") or "us"
    write("/etc/vconsole.conf", f"KEYMAP={console_keymap(keymap)}\n")
    write("/etc/X11/xorg.conf.d/00-keyboard.conf",
          'Section "InputClass"\n  Identifier "system-keyboard"\n  MatchIsKeyboard "on"\n'
          f'  Option "XkbLayout" "{keymap}"\nEndSection\n')
    host = cfg.get("hostname") or "fiordland"
    write("/etc/hostname", host + "\n")
    write("/etc/hosts", f"127.0.0.1 localhost\n::1 localhost\n127.0.1.1 {host}.localdomain {host}\n")

    status("Creating your account", 0.86)
    user = cfg["username"]
    full = cfg.get("fullname") or ""
    if not DRY:
        with open(MNT + "/etc/skel/.bashrc", "a") as f:
            f.write("\n[[ -r /usr/share/fiordland/bashrc ]] && . /usr/share/fiordland/bashrc\n")
    chroot("useradd", "-m", "-G", "wheel,video,input,audio", "-s", "/bin/bash", "-c", full, user)
    chroot("chpasswd", inp=f"{user}:{cfg['password']}\n")
    log(f"set password for {user}")
    chroot("passwd", "-l", "root")
    write("/etc/sudoers.d/10-wheel", "%wheel ALL=(ALL:ALL) ALL\n", 0o440)
    chroot("sed", "-i", f's/kb_layout = "[^"]*"/kb_layout = "{keymap}"/',
           f"/home/{user}/.config/hypr/hyprland.lua", check=False)

    status("Setting up services", 0.89)
    greet = (
        "[terminal]\nvt = 1\n\n[default_session]\n"
        'command = "tuigreet --time --remember --asterisks --greeting \'Welcome to Fiordland\' --cmd start-hyprland"\n'
        'user = "greeter"\n'
    )
    if cfg.get("autologin"):
        greet += f'\n[initial_session]\ncommand = "start-hyprland"\nuser = "{user}"\n'
    write("/etc/greetd/config.toml", greet)
    write("/etc/systemd/zram-generator.conf", "[zram0]\nzram-size = min(ram / 2, 8192)\ncompression-algorithm = zstd\n")
    write("/etc/sysctl.d/99-fiordland.conf",
          "vm.swappiness = 180\nvm.watermark_boost_factor = 0\nvm.watermark_scale_factor = 125\nvm.page-cluster = 0\n")
    snapper(user, root)
    for s in SERVICES:
        chroot("systemctl", "enable", s, check=False)
    chroot("flatpak", "remote-add", "--if-not-exists", "flathub",
           "https://dl.flathub.org/repo/flathub.flatpakrepo", check=False)
    chroot("flatpak", "update", "--appstream", "--system", "--noninteractive", check=False)

    status("Building the boot image", 0.92)
    kms = "" if GPU["nvidia"] else " kms"
    hooks = f"HOOKS=(base systemd autodetect microcode modconf{kms} keyboard sd-vconsole block filesystems fsck)"
    chroot("sed", "-i", f"s/^HOOKS=.*/{hooks}/", "/etc/mkinitcpio.conf")
    if GPU["modules"]:
        chroot("sed", "-i", f"s/^MODULES=.*/MODULES=({' '.join(GPU['modules'])})/", "/etc/mkinitcpio.conf")
    chroot("mkinitcpio", "-P")

    status("Installing the bootloader", 0.96)
    uuid = "" if DRY else subprocess.run(["blkid", "-s", "UUID", "-o", "value", root],
                                         capture_output=True, text=True).stdout.strip()
    extra = "".join(f" {p}" for p in GPU["params"])
    opts = f"root=UUID={uuid} rootflags=subvol=@ rw quiet loglevel=3 nowatchdog{extra}"
    if uefi:
        chroot("bootctl", "install", "--variables=yes")
        write("/boot/loader/loader.conf", "default fiordland.conf\ntimeout 2\nconsole-mode max\neditor no\n")
        write("/boot/loader/entries/fiordland.conf",
              f"title   Fiordland Linux\nlinux   /vmlinuz-linux\ninitrd  /initramfs-linux.img\noptions {opts}\n")
        safe = f"root=UUID={uuid} rootflags=subvol=@ rw nomodeset"
        write("/boot/loader/entries/fiordland-safe.conf",
              f"title   Fiordland Linux (safe graphics)\nlinux   /vmlinuz-linux\ninitrd  /initramfs-linux.img\noptions {safe}\n")
    else:
        chroot("grub-install", "--target=i386-pc", cfg["disk"])
        chroot("sed", "-i", "-e", 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Fiordland"/',
               "-e", 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=2/',
               "-e", f's|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3 nowatchdog{extra}"|',
               "/etc/default/grub")
        chroot("grub-mkconfig", "-o", "/boot/grub/grub.cfg")


def snapper(user, root):
    run(["umount", f"{MNT}/.snapshots"], check=False)
    run(["rm", "-rf", f"{MNT}/.snapshots"], check=False)
    chroot("snapper", "--no-dbus", "-c", "root", "create-config", "/", check=False)
    run(["btrfs", "subvolume", "delete", f"{MNT}/.snapshots"], check=False)
    run(["mkdir", "-p", f"{MNT}/.snapshots"], check=False)
    run(["mount", "-o", f"{MOUNT_OPTS},subvol=@snapshots", root, f"{MNT}/.snapshots"], check=False)
    run(["chmod", "750", f"{MNT}/.snapshots"], check=False)
    limits = {"ALLOW_USERS": user, "TIMELINE_LIMIT_HOURLY": "5", "TIMELINE_LIMIT_DAILY": "7",
              "TIMELINE_LIMIT_WEEKLY": "2", "TIMELINE_LIMIT_MONTHLY": "1", "TIMELINE_LIMIT_YEARLY": "0"}
    args = []
    for k, v in limits.items():
        args += ["-e", f's/^{k}=.*/{k}="{v}"/']
    chroot("sed", "-i", *args, "/etc/snapper/configs/root", check=False)


def console_keymap(xkb):
    mapping = {"gb": "uk", "us": "us", "de": "de", "fr": "fr", "es": "es", "it": "it", "pt": "pt-latin1",
               "br": "br-abnt2", "se": "sv-latin1", "no": "no", "dk": "dk", "fi": "fi", "pl": "pl",
               "ru": "ru", "cz": "cz", "hu": "hu", "nl": "nl", "be": "be-latin1", "ch": "ch",
               "jp": "jp106", "latam": "la-latin1", "tr": "trq", "ua": "ua"}
    return mapping.get(xkb, "us")


def finish():
    status("Finishing up", 0.99)
    run(["sync"], check=False)
    run(["gpgconf", "--homedir", f"{MNT}/etc/pacman.d/gnupg", "--kill", "gpg-agent"], check=False)
    run(["fuser", "-km", MNT], check=False)
    run(["umount", "-R", MNT], check=False)


def main():
    global DRY
    args = sys.argv[1:]
    DRY = "--dry-run" in args
    args = [a for a in args if a != "--dry-run"]
    if not args:
        print("usage: engine.py [--dry-run] config.json", file=sys.stderr)
        sys.exit(2)
    with open(args[0]) as f:
        cfg = json.load(f)
    try:
        os.unlink(args[0])
    except OSError:
        pass
    try:
        root, uefi = partition(cfg)
        pkgs = list(PACKAGES)
        vendor = cpu_vendor()
        if vendor:
            pkgs.append(f"{vendor}-ucode")
        if not is_uefi():
            pkgs.append("grub")
        GPU.update(gpu_setup(gpus()))
        pkgs += GPU["pkgs"]
        SERVICES.extend(GPU["services"])
        gpkgs, gsvcs = guest_tools()
        pkgs += gpkgs
        SERVICES.extend(gsvcs)
        pacstrap(pkgs)
        configure(cfg, root, uefi)
        finish()
        emit(progress=1.0, status="Fiordland is installed", done=True)
    except Exception as e:
        log(f"error: {e}")
        run(["umount", "-R", MNT], check=False)
        emit(error=str(e))
        sys.exit(1)


if __name__ == "__main__":
    main()

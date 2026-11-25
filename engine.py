#!/usr/bin/env python3
import glob
import json
import os
import re
import subprocess
import sys
import tempfile
import time

import checks
import desktops
import disks

MNT = "/mnt"
LOCAL_REPO = "/opt/fiordland/repo"

PACKAGES = [
    "base", "linux", "linux-firmware", "btrfs-progs", "dosfstools", "networkmanager", "sudo", "nano",
    "upower", "libnotify", "pipewire", "pipewire-pulse", "pipewire-alsa", "wireplumber",
    "noto-fonts", "noto-fonts-emoji", "inter-font", "ttf-jetbrains-mono", "firefox",
    "bluez", "bluez-utils", "flatpak", "tawaki", "fiordland-base", "fiordland-desktop", "fiordland-keyring", "fastfetch", "git",
    "base-devel", "zram-generator", "man-db", "xdg-user-dirs", "xdg-utils", "papirus-icon-theme",
    "snapper", "snap-pac", "pacman-contrib", "power-profiles-daemon", "sof-firmware", "alsa-firmware", "reflector",
    "cups", "cups-filters", "cups-pk-helper", "ghostscript", "avahi", "nss-mdns", "ufw", "fwupd",
    "ntfs-3g", "exfatprogs", "udisks2", "pkgfile", "unzip", "zip", "7zip",
    "grub", "grub-btrfs", "inotify-tools", "os-prober", "openssh",
]

SERVICES = [
    "NetworkManager", "bluetooth", "systemd-timesyncd", "fstrim.timer",
    "power-profiles-daemon", "snapper-timeline.timer", "snapper-cleanup.timer", "reflector.timer",
    "tawaki-catalogue.timer", "cups.socket", "avahi-daemon", "ufw", "systemd-oomd",
    "fwupd-refresh.timer", "paccache.timer", "pkgfile-update.timer", "grub-btrfsd",
]

SUBVOLS = [("@", ""), ("@home", "home"), ("@log", "var/log"), ("@pkg", "var/cache/pacman/pkg"), ("@snapshots", ".snapshots")]
MOUNT_OPTS = "noatime,compress=zstd:1"
FIORD_REPO = "[fiordland]\nSigLevel = Required\nServer = https://fiordlandlinux.org/repo/$arch\n\n"
CACHY_REPO = "\n[cachyos]\nInclude = /etc/pacman.d/cachyos-mirrorlist\n"
CACHY_PKGS = ["cachyos-keyring", "cachyos-mirrorlist"]
GAMING = ["fiordland-gaming"]
KERNEL_PKGS = {"cachyos": ["linux-cachyos"], "fiord": ["linux-fiord"], "arch": []}
KERNEL = {"name": "cachyos", "repo": True}
GREETER = {"name": ""}
CREST_GREETER = ["crest-greeter"]
ESP_MNT = "/efi"
MODE = {"alongside": False}
STABLE_SERVER = "https://fiordlandlinux.org/stable/$repo/os/$arch"
CHANNEL = {"name": "rolling", "server": STABLE_SERVER}

XFCE_LOOK = r"""#!/bin/sh
sleep 2
set_prop() { xfconf-query -c "$1" -p "$2" -n -t "$3" -s "$4" 2>/dev/null || xfconf-query -c "$1" -p "$2" -s "$4"; }
set_prop xsettings /Net/ThemeName string Adwaita-dark
set_prop xsettings /Net/IconThemeName string Fiordland
set_prop xsettings /Gtk/FontName string "Inter 10"
set_prop xsettings /Gtk/MonospaceFontName string "JetBrains Mono 10"
set_prop xfwm4 /general/title_font string "Inter Bold 10"
set_prop xfce4-desktop /desktop-icons/use-custom-label-text-color bool true
set_prop xfce4-desktop /desktop-icons/use-custom-label-background-color bool true
xfconf-query -c xfce4-desktop -p /desktop-icons/label-text-color -n -t double -t double -t double -t double -s 0.914 -s 0.918 -s 0.925 -s 1 2>/dev/null
xfconf-query -c xfce4-desktop -p /desktop-icons/label-background-color -n -t double -t double -t double -t double -s 0 -s 0 -s 0 -s 0 2>/dev/null
if systemd-detect-virt --vm -q; then
  set_prop xfce4-power-manager /xfce4-power-manager/dpms-enabled bool false
  set_prop xfce4-power-manager /xfce4-power-manager/blank-on-ac int 0
  set_prop xfce4-screensaver /saver/enabled bool false
  set_prop xfce4-screensaver /lock/enabled bool false
fi
for _ in $(seq 20); do
  pgrep -u "$(id -u)" -x xfdesktop >/dev/null && break
  sleep 1
done
for s in /sys/class/drm/card*-*; do
  [ "$(cat "$s/status" 2>/dev/null)" = connected ] || continue
  m=monitor${s##*/card[0-9]-}
  for w in 0 1 2 3; do
    set_prop xfce4-desktop "/backdrop/screen0/$m/workspace$w/last-image" string /usr/share/fiordland/wallpaper.png
    set_prop xfce4-desktop "/backdrop/screen0/$m/workspace$w/image-style" int 5
  done
done
rm -f "$HOME/.config/autostart/fiordland-xfce-look.desktop"
"""

DRY = False
TAIL = 20


class CommandFailed(RuntimeError):
    def __init__(self, msg, tail):
        super().__init__(msg)
        self.tail = tail


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
        out = [l for l in (p.stderr or p.stdout).splitlines() if l.strip()]
        raise CommandFailed(f"{cmd[0]} failed ({p.returncode})", out[-TAIL:])
    return p.stdout


def chroot(*cmd, inp=None, check=True):
    return run(["arch-chroot", MNT, *cmd], inp=inp, check=check)


def write(path, text, mode=0o644):
    full = MNT + path
    log(f"write {path}")
    if DRY:
        return
    os.makedirs(os.path.dirname(full), exist_ok=True)
    fd = os.open(full, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, mode)
    with os.fdopen(fd, "w") as f:
        os.fchmod(f.fileno(), mode)
        f.write(text)


def part_name(disk, n):
    return checks.partition_name(disk, n)


def erase_cmds(disk, uefi):
    if uefi:
        first = ["-n1:0:+512M", "-t1:ef00", "-c1:EFI"]
    else:
        first = ["-n1:0:+1M", "-t1:ef02", "-c1:BIOS"]
    return [
        ["wipefs", "-af", disk],
        ["sgdisk", "--zap-all", disk],
        ["sgdisk", *first, "-n2:0:0", "-t2:8304", "-c2:Fiordland", disk],
    ]


def useradd_cmd(user, full):
    if checks.username_error(user) or checks.fullname_error(full):
        raise ValueError("bad account details")
    return ["useradd", "-m", "-G", "wheel,video,input,audio", "-s", "/bin/bash", "-c", full, "--", user]


def chpasswd_input(user, password):
    if checks.username_error(user) or checks.password_error(password):
        raise ValueError("bad account details")
    return f"{user}:{password}\n"


def kernel_packages(kernel, gpu_pkgs):
    pkgs = list(KERNEL_PKGS.get(kernel, []))
    gpu = list(gpu_pkgs)
    if kernel != "cachyos":
        gpu = [p for p in gpu if not p.startswith("linux-cachyos")]
    if kernel == "fiord" and "nvidia-open" in gpu:
        gpu = ["nvidia-open-dkms" if p == "nvidia-open" else p for p in gpu]
        pkgs += ["linux-fiord-headers", "linux-headers"]
    return pkgs, gpu


def build_packages(cfg, vendor, uefi, gpu_pkgs, guest_pkgs):
    pkgs = list(PACKAGES)
    pkgs += [p for p in desktops.packages(cfg["desktop"], cfg["shell"]) if p not in pkgs]
    if vendor:
        pkgs.append(f"{vendor}-ucode")
    if uefi:
        pkgs.append("efibootmgr")
    kpkgs, gpu = kernel_packages(cfg["kernel"], gpu_pkgs)
    if cfg.get("lowend"):
        gpu = [p for p in gpu if not p.startswith("lib32-")]
    pkgs += gpu + list(guest_pkgs) + CACHY_PKGS
    if not cfg.get("lowend"):
        pkgs += GAMING
    pkgs += kpkgs
    if cfg.get("greeter") == "crest":
        pkgs += CREST_GREETER
    seen = set()
    return [p for p in pkgs if not (p in seen or seen.add(p))]


def fallback_packages(pkgs):
    drop = set(CACHY_PKGS + GAMING + CREST_GREETER + ["linux-fiord-headers", "linux-headers"])
    out = []
    for p in pkgs:
        if p in drop or p.startswith(("linux-cachyos", "linux-fiord")):
            continue
        out.append("nvidia-open" if p == "nvidia-open-dkms" else p)
    return out


def greetd_config(cmd, user, autologin, greeter=""):
    if greeter == "crest":
        session = 'command = "crest-greeter"\n'
    else:
        session = (f'command = "tuigreet --time --remember --remember-session --asterisks '
                   f'--greeting \'Welcome to Fiordland\' --cmd {cmd}"\n')
    text = "[terminal]\nvt = 1\n\n[default_session]\n" + session + 'user = "greeter"\n'
    if autologin:
        text += f'\n[initial_session]\ncommand = "{cmd}"\nuser = "{user}"\n'
    return text


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
        g["pkgs"] += ["nvidia-open", "linux-cachyos-nvidia-open", "nvidia-utils", "lib32-nvidia-utils", "nvidia-settings",
                      "egl-wayland", "libva-nvidia-driver"]
        g["services"] += ["nvidia-suspend", "nvidia-hibernate", "nvidia-resume"]
        g["modules"] += ["nvidia", "nvidia_modeset", "nvidia_uvm", "nvidia_drm"]
        g["params"] += ["nvidia_drm.modeset=1", "nvidia_drm.fbdev=1"]
    elif nv:
        g["pkgs"] += ["vulkan-nouveau", "lib32-vulkan-nouveau"]
    if not g["nvidia"] and not any(p.startswith("vulkan-") for p in g["pkgs"]):
        g["pkgs"] += ["vulkan-swrast", "lib32-vulkan-swrast"]
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


def mounted(path):
    return not DRY and os.path.ismount(path)


def disk_nodes(disk):
    return (run(["lsblk", "-lnpo", "NAME", disk], check=False) or "").split()


def stop_agents():
    run(["gpgconf", "--homedir", f"{MNT}/etc/pacman.d/gnupg", "--kill", "all"], check=False)
    for name in ("gpg-agent", "dirmngr", "keyboxd"):
        run(["pkill", "-x", name], check=False)


def release_mnt():
    stop_agents()
    if not mounted(MNT):
        return
    run(["sync"], check=False)
    run(["fuser", "-km", MNT], check=False)
    run(["umount", "-R", MNT], check=False)
    if mounted(MNT):
        time.sleep(1)
        run(["umount", "-R", MNT], check=False)
    if mounted(MNT):
        run(["umount", "-lR", MNT], check=False)


def release_disk(disk):
    release_mnt()
    nodes = disk_nodes(disk)
    if not DRY:
        with open("/proc/swaps") as f:
            swaps = [l.split()[0] for l in f.read().splitlines()[1:] if l.strip()]
        for dev in swaps:
            if os.path.realpath(dev) in nodes:
                run(["swapoff", dev], check=False)
    for node in nodes[1:]:
        run(["umount", node], check=False)
    settle(disk)
    if DRY:
        return
    busy = (run(["lsblk", "-lnpo", "NAME,MOUNTPOINTS", disk], check=False) or "").splitlines()
    busy = [l.split(None, 1) for l in busy if len(l.split(None, 1)) == 2]
    if busy:
        raise CommandFailed("The target disk is still in use", [f"{n} mounted at {m}" for n, m in busy])


def settle(disk):
    run(["partprobe", disk], check=False)
    run(["udevadm", "settle"], check=False)


def confirm_parts(disk, parts):
    if DRY:
        return
    for part in parts:
        checks.check_partition(disk, part)


def erase(disk, uefi):
    status("Preparing your disk", 0.01)
    for cmd in erase_cmds(disk, uefi):
        run(cmd)
    settle(disk)
    esp, root = part_name(disk, 1), part_name(disk, 2)
    confirm_parts(disk, [esp, root])
    if uefi:
        status("Formatting", 0.03)
        run(["mkfs.fat", "-F32", "-n", "EFI", esp])
    return esp if uefi else "", root


def alongside(cfg):
    disk = cfg["disk"]
    status("Checking your disk", 0.01)
    if DRY:
        log(f"alongside on {disk}: {cfg.get('shrink') or 'free space'}, {cfg.get('size')} bytes")
        return part_name(disk, 1), part_name(disk, 9)
    info = disks.probe(disk)
    want = cfg.get("shrink") or ""
    opt = next((o for o in info["options"] if o["part"] == want), None)
    if not opt or not info["esp"]:
        raise RuntimeError("This disk can no longer be shared; go back and choose again")
    size = int(cfg.get("size") or opt["max"])
    size = max(opt["min"], min(size, opt["max"]))
    pt = disks.table(disk)
    sector = pt.get("sectorsize", 512)
    if opt["kind"] == "shrink":
        part = opt["part"]
        before = disks.snapshot(disk)[part]
        keep_part = (opt["partSize"] - size) // disks.MIB * disks.MIB
        keep_fs = keep_part - disks.MIB
        status(f"Shrinking {opt['label']}", 0.02)
        run(["ntfsresize", "--no-action", "--no-progress-bar", "--size", str(keep_fs), part])
        run(["ntfsresize", "--no-progress-bar", "--size", str(keep_fs), part], inp="y\n")
        num = re.search(r"(\d+)$", part).group(1)
        run(["sfdisk", "--no-reread", "--no-tell-kernel", "-N", num, disk], inp=f",{keep_part // sector}\n")
        settle(disk)
        after = disks.snapshot(disk)[part]
        if after.get("uuid") != before.get("uuid") or after["start"] != before["start"]:
            raise RuntimeError("Windows partition changed unexpectedly after resizing")
        run(["ntfsresize", "--info", "--force", "--no-progress-bar", part])
        whole = True
    else:
        whole = size >= opt["max"] - disks.MIB
    status("Creating the Fiordland partition", 0.03)
    old = set(disks.snapshot(disk))
    end = "0" if whole else f"+{size // disks.MIB}M"
    run(["sgdisk", f"-n0:0:{end}", "-t0:8304", "-c0:Fiordland", disk])
    settle(disk)
    new = sorted(set(disks.snapshot(disk)) - old)
    if len(new) != 1:
        raise RuntimeError("Could not find the new partition")
    confirm_parts(disk, [info["esp"], new[0]])
    return info["esp"], new[0]


def manual(cfg, uefi):
    disk = cfg["disk"]
    root = cfg.get("root") or ""
    esp = cfg.get("esp") or ""
    status("Checking your partitions", 0.01)
    if DRY:
        log(f"manual on {disk}: root {root}, esp {esp}")
        return esp, root
    info = disks.probe(disk, uefi)
    parts = {p["node"]: p for p in info["parts"]}
    if root not in parts or not parts[root]["usable"]:
        raise RuntimeError("The partition chosen for Fiordland is gone or too small; go back and choose again")
    if uefi:
        if esp not in parts or not parts[esp]["esp"] or parts[esp]["fs"] != "vfat":
            raise RuntimeError("Choose a FAT32 EFI system partition for the boot files")
    elif info["gpt"] and not info["biosBoot"]:
        raise RuntimeError("This GPT disk needs a 1 MB BIOS boot partition for GRUB. Create one in the partition editor")
    confirm_parts(disk, [root] + ([esp] if uefi else []))
    run(["wipefs", "-af", root])
    if info["gpt"]:
        num = re.search(r"(\d+)$", root).group(1)
        run(["sgdisk", f"-t{num}:8304", f"-c{num}:Fiordland", disk], check=False)
        settle(disk)
    return esp if uefi else "", root


def partition(cfg):
    disk = cfg["disk"]
    uefi = is_uefi()
    release_disk(disk)
    mode = cfg.get("mode")
    MODE["alongside"] = mode in ("alongside", "manual")
    if mode == "manual":
        esp, root = manual(cfg, uefi)
    elif mode == "alongside":
        if not uefi:
            raise RuntimeError("Installing alongside needs UEFI")
        esp, root = alongside(cfg)
    else:
        esp, root = erase(disk, uefi)
    status("Formatting", 0.04)
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
            os.makedirs(MNT + ESP_MNT, exist_ok=True)
        run(["mount", "-o", "umask=0077", esp, MNT + ESP_MNT])
    return root, uefi


def pacman_conf():
    with open("/etc/pacman.conf") as f:
        base = f.read()
    base = re.sub(r"(?ms)^\[fiordland\].*?(?=^\[|\Z)", "", base)
    repo = f"[fiordland]\nSigLevel = Required\nServer = file://{LOCAL_REPO}\n\n"
    base = base.replace("[core]", repo + "[core]", 1)
    base = re.sub(r"(?m)^#?ParallelDownloads.*$", "ParallelDownloads = 10", base)
    base = re.sub(r"(?m)^#\[multilib\]\n#Include", "[multilib]\nInclude", base)
    base = re.sub(r"(?ms)^\[cachyos\].*?(?=^\[|\Z)", "", base)
    if CHANNEL["name"] == "stable":
        base = pin_arch_repos(base, "Server = " + CHANNEL["server"])
    if KERNEL["repo"]:
        base = base.rstrip("\n") + "\n" + CACHY_REPO
    fd, path = tempfile.mkstemp(prefix="rawaru-pacman-", suffix=".conf")
    with os.fdopen(fd, "w") as f:
        f.write(base)
    return path


def pin_arch_repos(conf, line):
    out, inside = [], False
    for l in conf.splitlines():
        if re.match(r"^\[(core|extra|multilib)\]", l):
            inside = True
        elif l.startswith("["):
            inside = False
        elif inside and re.match(r"^(Include|Server)\s*=", l):
            if out and out[-1] == line:
                continue
            l = line
        out.append(l)
    return "\n".join(out) + "\n"


def pacstrap_cmd(conf, pkgs):
    bad = [p for p in pkgs if not re.fullmatch(r"[a-z0-9@_+][a-z0-9@._+-]*", p)]
    if bad:
        raise ValueError(f"bad package name {bad[0]!r}")
    return ["pacstrap", "-K", "-C", conf, MNT, "--noconfirm", "--needed", *pkgs]


def pacstrap(pkgs):
    status("Downloading packages", 0.05)
    if not DRY and not os.path.ismount(MNT):
        raise RuntimeError(f"{MNT} is not mounted, refusing to install into the live system")
    if DRY:
        total = len(pkgs)
        for i, p in enumerate(pkgs):
            time.sleep(0.04)
            status(f"Downloading {p}", 0.08 + 0.37 * (i + 1) / total)
        for i, p in enumerate(pkgs):
            time.sleep(0.04)
            status(f"Installing {p}", 0.45 + 0.37 * (i + 1) / total)
        return
    if CHANNEL["name"] != "stable":
        status("Finding the fastest mirrors", 0.05)
        run(["timeout", "50", "systemctl", "start", "fiordland-mirrors.service"], check=False)
    status("Downloading packages", 0.06)
    conf = pacman_conf()
    try:
        cmd = pacstrap_cmd(conf, pkgs)
        log("$ " + " ".join(cmd))
        env = dict(os.environ, LC_ALL="C")
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env, bufsize=1)
        total = None
        dl = inst = 0
        tail = []
        re_total = re.compile(r"^Packages \((\d+)\)")
        re_inst = re.compile(r"^\(\s*(\d+)/(\d+)\) installing (\S+)")
        for raw in p.stdout:
            line = raw.rstrip()
            if not line:
                continue
            log(line)
            tail = (tail + [line])[-TAIL:]
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
    finally:
        try:
            os.unlink(conf)
        except OSError:
            pass
    if p.returncode != 0:
        raise CommandFailed(f"pacstrap failed ({p.returncode})", tail)


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
        if KERNEL["repo"] and "[cachyos]" not in pc:
            pc = pc.rstrip("\n") + "\n" + CACHY_REPO
        with open(f"{MNT}/etc/pacman.conf", "w") as f:
            f.write(pc)
    log("added [fiordland] repo" + (" and [cachyos]" if KERNEL["repo"] else ""))
    if KERNEL["repo"]:
        chroot("pacman-key", "--populate", "cachyos", check=False)
    set_channel()
    tz = cfg.get("timezone") or "UTC"
    if checks.timezone_error(tz) or (not DRY and not os.path.isfile(f"{MNT}/usr/share/zoneinfo/{tz}")):
        log(f"unknown time zone {tz!r}, using UTC")
        tz = "UTC"
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
    chroot(*useradd_cmd(user, full))
    chroot("chpasswd", inp=chpasswd_input(user, cfg["password"]))
    cfg["password"] = ""
    log(f"set password for {user}")
    chroot("passwd", "-l", "root")
    write("/etc/sudoers.d/10-wheel", "%wheel ALL=(ALL:ALL) ALL\n", 0o440)

    status("Setting up your desktop", 0.88)
    desktop(cfg, user, keymap)
    write("/etc/systemd/zram-generator.conf", "[zram0]\nzram-size = min(ram / 2, 8192)\ncompression-algorithm = zstd\n")
    write("/etc/sysctl.d/99-fiordland.conf",
          "vm.swappiness = 180\nvm.watermark_boost_factor = 0\nvm.watermark_scale_factor = 125\nvm.page-cluster = 0\n")
    snapper(user, root)
    services_config()
    for s in SERVICES:
        chroot("systemctl", "enable", s, check=False)
    chroot("flatpak", "remote-add", "--if-not-exists", "flathub",
           "https://dl.flathub.org/repo/flathub.flatpakrepo", check=False)
    chroot("flatpak", "update", "--appstream", "--system", "--noninteractive", check=False)

    status("Building the boot image", 0.92)
    kms = "" if GPU["nvidia"] else " kms"
    hooks = f"HOOKS=(base udev autodetect microcode modconf{kms} keyboard keymap consolefont block filesystems fsck grub-btrfs-overlayfs)"
    chroot("sed", "-i", f"s/^HOOKS=.*/{hooks}/", "/etc/mkinitcpio.conf")
    if GPU["modules"]:
        chroot("sed", "-i", f"s/^MODULES=.*/MODULES=({' '.join(GPU['modules'])})/", "/etc/mkinitcpio.conf")
    chroot("mkinitcpio", "-P")
    bootloader(cfg, root, uefi)


def set_channel():
    if CHANNEL["name"] != "stable":
        return
    if not DRY and not os.path.exists(MNT + "/usr/bin/fiordland-channel"):
        log("this fiordland-base has no stable channel yet, staying on rolling")
        return
    if CHANNEL["server"] != STABLE_SERVER:
        write("/etc/pacman.d/fiordland-stable", f"Server = {CHANNEL['server']}\n")
    chroot("fiordland-channel", "stable")


def bootloader(cfg, root, uefi):
    status("Installing the bootloader", 0.96)
    uuid = "" if DRY else subprocess.run(["blkid", "-s", "UUID", "-o", "value", root],
                                         capture_output=True, text=True).stdout.strip()
    extra = "".join(f" {p}" for p in GPU["params"])
    if uefi:
        chroot("grub-install", "--target=x86_64-efi", f"--efi-directory={ESP_MNT}", "--bootloader-id=Fiordland")
        if not MODE["alongside"]:
            chroot("grub-install", "--target=x86_64-efi", f"--efi-directory={ESP_MNT}", "--removable", check=False)
    else:
        chroot("grub-install", "--target=i386-pc", cfg["disk"])
    timeout = "5" if MODE["alongside"] else "3"
    chroot("sed", "-i", "-e", 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Fiordland"/',
           "-e", f"s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT={timeout}/",
           "-e", f's|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3 nowatchdog{extra}"|',
           "-e", "s/^#\\?GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/",
           "/etc/default/grub")
    if not DRY:
        with open(f"{MNT}/etc/default/grub") as f:
            g = f.read()
        if "GRUB_DISABLE_OS_PROBER=false" not in g:
            g += "\nGRUB_DISABLE_OS_PROBER=false\n"
        g += "\nGRUB_DISABLE_BOOTNEXT=true\n"
        top = KERNEL_PKGS.get(KERNEL["name"])
        if top:
            g += f'\nGRUB_TOP_LEVEL="/boot/vmlinuz-{top[0]}"\n'
        with open(f"{MNT}/etc/default/grub", "w") as f:
            f.write(g)
    write("/etc/grub.d/11_fiordland_safe",
          '#!/bin/sh\nexec tail -n +3 "$0"\n'
          "menuentry 'Fiordland Linux (safe graphics)' --class fiordland --class gnu-linux {\n"
          f"    search --no-floppy --fs-uuid --set=root {uuid}\n"
          f"    linux /@/boot/vmlinuz-linux root=UUID={uuid} rootflags=subvol=@ rw nomodeset\n"
          "    initrd /@/boot/initramfs-linux.img\n"
          "}\n", 0o755)
    chroot("sed", "-i", "-e", 's/^#\\?GRUB_BTRFS_SUBMENUNAME=.*/GRUB_BTRFS_SUBMENUNAME="Fiordland snapshots"/',
           "-e", 's/^#\\?GRUB_BTRFS_LIMIT=.*/GRUB_BTRFS_LIMIT="20"/',
           "/etc/default/grub-btrfs/config")
    chroot("grub-mkconfig", "-o", "/boot/grub/grub.cfg")


def home(user, path, text, mode=0o644):
    write(f"/home/{user}/{path}", text, mode)


def from_system(path):
    try:
        with open(MNT + path) as f:
            return f.read()
    except OSError:
        return ""


def login_manager(d, user, autologin):
    dm = d["dm"]
    session = d["session"]
    if dm == "sddm":
        conf = "[Theme]\nCurrent=breeze\n" if d["id"] == "plasma" else ""
        if autologin:
            conf += f"\n[Autologin]\nUser={user}\nSession={session}.desktop\n"
        write("/etc/sddm.conf.d/10-fiordland.conf", conf or "[General]\n")
        return "sddm"
    if dm == "gdm":
        if autologin:
            write("/etc/gdm/custom.conf", f"[daemon]\nAutomaticLoginEnable=True\nAutomaticLogin={user}\n")
        return "gdm"
    if dm == "cosmic":
        if autologin and not DRY:
            conf = from_system("/etc/greetd/cosmic-greeter.toml")
            if "[initial_session]" not in conf:
                conf = conf.rstrip("\n") + f'\n\n[initial_session]\ncommand = "start-cosmic"\nuser = "{user}"\n'
                write("/etc/greetd/cosmic-greeter.toml", conf)
        return "cosmic-greeter"
    if dm == "lightdm":
        greeter = d.get("greeter", "lightdm-gtk-greeter")
        conf = f"[Seat:*]\ngreeter-session={greeter}\nuser-session={session}\n"
        if autologin:
            conf += f"autologin-user={user}\nautologin-session={session}\n"
            chroot("groupadd", "-rf", "autologin", check=False)
            chroot("gpasswd", "-a", user, "autologin", check=False)
        write("/etc/lightdm/lightdm.conf.d/50-fiordland.conf", conf)
        if greeter == "lightdm-gtk-greeter":
            write("/etc/lightdm/lightdm-gtk-greeter.conf",
                  "[greeter]\nbackground=/usr/share/fiordland/wallpaper.png\ntheme-name=Adwaita-dark\n"
                  "icon-theme-name=Fiordland\nfont-name=Inter 11\n")
        return "lightdm"
    greeter = GREETER["name"]
    if greeter == "crest" and not DRY and not os.path.exists(MNT + "/usr/bin/crest-greeter"):
        log("crest-greeter is not installed, using tuigreet")
        greeter = ""
    write("/etc/greetd/config.toml", greetd_config(d["cmd"], user, autologin, greeter))
    return "greetd"


def desktop(cfg, user, keymap):
    d, shell = desktops.resolve(cfg.get("desktop", "plasma"), cfg.get("shell"))
    did = d["id"]
    log(f"desktop {did}" + (f" with {shell}" if shell else ""))
    SERVICES.append(login_manager(d, user, cfg.get("autologin")))
    script = shell and "script" in desktops.SHELLS[shell]
    if script:
        home(user, ".config/fiordland/dots", desktops.SHELLS[shell]["script"] + "\n")
    wall = "/usr/share/fiordland/wallpaper.png"
    run_cmd = desktops.SHELLS[shell].get("run") if shell and not script else None

    if did == "plasma":
        home(user, ".config/autostart/fiordland-wallpaper.desktop",
             "[Desktop Entry]\nType=Application\nName=Fiordland wallpaper\nNoDisplay=true\n"
             f"Exec=sh -c 'plasma-apply-wallpaperimage {wall} && rm -f ~/.config/autostart/fiordland-wallpaper.desktop'\n")
        if keymap != "us":
            home(user, ".config/kxkbrc", f"[Layout]\nLayoutList={keymap}\nUse=true\n")
    elif did == "xfce":
        home(user, ".local/share/fiordland/xfce-look.sh", XFCE_LOOK, 0o755)
        home(user, ".config/autostart/fiordland-xfce-look.desktop",
             "[Desktop Entry]\nType=Application\nName=Fiordland look\nNoDisplay=true\n"
             f"Exec=sh /home/{user}/.local/share/fiordland/xfce-look.sh\n")
    elif did == "hyprland":
        conf = from_system("/usr/share/fiordland/hyprland.lua")
        conf = re.sub(r'(?m)^local shell = "[^"]*"', f'local shell = "{"dots" if script else shell}"', conf)
        conf = re.sub(r'kb_layout = "[^"]*"', f'kb_layout = "{keymap}"', conf)
        home(user, ".config/hypr/hyprland.lua", conf)
    elif did == "niri":
        conf = from_system("/usr/share/doc/niri/default-config.kdl")
        extra = ['spawn-at-startup "fiordland-dots"']
        if shell == "none":
            extra += ['spawn-at-startup "mako"', f'spawn-at-startup "swaybg" "-m" "fill" "-i" "{wall}"']
        elif run_cmd:
            conf = re.sub(r'(?m)^spawn-at-startup "waybar"\n', "", conf)
            extra.append("spawn-at-startup " + " ".join(f'"{w}"' for w in run_cmd.split()))
        home(user, ".config/niri/config.kdl", conf.rstrip("\n") + "\n\n" + "\n".join(extra) + "\n")
    elif did == "sway":
        conf = from_system("/etc/sway/config")
        conf = re.sub(r"(?m)^output \* bg .*$", f"output * bg {wall} fill", conf)
        if run_cmd:
            conf = re.sub(r"(?ms)^bar \{.*?^\}\n", "", conf)
            conf = conf.replace("\ninclude ", f"\nexec {run_cmd}\n\ninclude ", 1)
        conf += f"\ninput type:keyboard xkb_layout {keymap}\n"
        home(user, ".config/sway/config", conf)
    elif did == "labwc":
        auto = [f"swaybg -m fill -i {wall} &", "nm-applet --indicator &"]
        auto += [f"{run_cmd} &"] if run_cmd else ["waybar &", "mako &"]
        home(user, ".config/labwc/autostart", "\n".join(auto) + "\n")
        home(user, ".config/labwc/environment", f"XKB_DEFAULT_LAYOUT={keymap}\n")
    elif did == "i3":
        conf = from_system("/etc/i3/config")
        conf += f"\nexec --no-startup-id feh --no-fehbg --bg-fill {wall}\n"
        home(user, ".config/i3/config", conf)
    elif did == "bspwm":
        rc = from_system("/usr/share/doc/bspwm/examples/bspwmrc")
        rc += f"\nfeh --no-fehbg --bg-fill {wall} &\nnm-applet &\n"
        home(user, ".config/bspwm/bspwmrc", rc, 0o755)
        keys = from_system("/usr/share/doc/bspwm/examples/sxhkdrc").replace("urxvt", "kitty")
        home(user, ".config/sxhkd/sxhkdrc", keys)
    elif did == "awesome":
        rc = from_system("/etc/xdg/awesome/rc.lua").replace('terminal = "xterm"', 'terminal = "kitty"')
        home(user, ".config/awesome/rc.lua", rc)
    elif did == "openbox":
        home(user, ".config/openbox/autostart", f"feh --no-fehbg --bg-fill {wall} &\ntint2 &\nnm-applet &\n")

    if d["kind"] == "wm":
        env = from_system("/etc/environment")
        if "TERMINAL=" not in env:
            write("/etc/environment", env + "TERMINAL=kitty\n")
    chroot("chown", "-R", f"{user}:{user}", f"/home/{user}")


def services_config():
    if DRY:
        log("configure firewall, mdns")
        return
    conf = MNT + "/etc/ufw/ufw.conf"
    if os.path.exists(conf):
        with open(conf) as f:
            text = f.read()
        write("/etc/ufw/ufw.conf", re.sub(r"(?m)^ENABLED=.*", "ENABLED=yes", text))
    ns = MNT + "/etc/nsswitch.conf"
    if os.path.exists(ns):
        with open(ns) as f:
            text = f.read()
        if "mdns_minimal" not in text:
            text = re.sub(r"(?m)^(hosts:.*?)\bresolve\b", r"\1mdns_minimal [NOTFOUND=return] resolve", text, count=1)
            write("/etc/nsswitch.conf", text)


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
    chroot("fiordland-migrate", "--stamp", check=False)


def console_keymap(xkb):
    mapping = {"gb": "uk", "us": "us", "de": "de", "fr": "fr", "es": "es", "it": "it", "pt": "pt-latin1",
               "br": "br-abnt2", "se": "sv-latin1", "no": "no", "dk": "dk", "fi": "fi", "pl": "pl",
               "ru": "ru", "cz": "cz", "hu": "hu", "nl": "nl", "be": "be-latin1", "ch": "ch",
               "jp": "jp106", "latam": "la-latin1", "tr": "trq", "ua": "ua"}
    return mapping.get(xkb, "us")


def default_channel():
    try:
        with open("/etc/rawaru/channel") as f:
            c = f.read().strip()
    except OSError:
        return "rolling"
    return c if c in ("stable", "rolling") else "rolling"


def finish():
    status("Finishing up", 0.99)
    release_mnt()


def read_config(arg, stdin=None):
    if arg == "-":
        text = (stdin or sys.stdin).read(1 << 20)
    else:
        with open(arg) as f:
            text = f.read(1 << 20)
        try:
            os.unlink(arg)
        except OSError:
            pass
    return checks.validate_config(json.loads(text))


def main():
    global DRY
    args = sys.argv[1:]
    DRY = "--dry-run" in args
    args = [a for a in args if a != "--dry-run"]
    if len(args) == 2 and args[0] == "--probe":
        err = checks.disk_error(args[1])
        if err:
            print(err, file=sys.stderr)
            sys.exit(2)
        print(json.dumps(disks.probe(args[1])))
        return
    if len(args) != 1:
        print("usage: engine.py [--dry-run] config.json|- | --probe DISK", file=sys.stderr)
        sys.exit(2)
    try:
        cfg = read_config(args[0])
        if not DRY:
            checks.check_target(cfg["disk"], cfg["disk_size"])
    except (OSError, ValueError) as e:
        emit(error=str(e) or "The install settings are not valid", detail="")
        sys.exit(1)
    try:
        root, uefi = partition(cfg)
        KERNEL["name"] = cfg["kernel"]
        GREETER["name"] = cfg["greeter"]
        CHANNEL["name"] = cfg["channel"] or default_channel()
        CHANNEL["server"] = cfg["stable_server"] or STABLE_SERVER
        log(f"channel {CHANNEL['name']}, kernel {KERNEL['name']}" + (", low-end defaults" if cfg["lowend"] else ""))
        GPU.update(gpu_setup(gpus()))
        SERVICES.extend(GPU["services"])
        gpkgs, gsvcs = guest_tools()
        SERVICES.extend(gsvcs)
        pkgs = build_packages(cfg, cpu_vendor(), is_uefi(), GPU["pkgs"], gpkgs)
        try:
            pacstrap(pkgs)
        except RuntimeError:
            if not KERNEL["repo"]:
                raise
            log("Optional packages unavailable, falling back to the Arch kernel")
            KERNEL["name"] = "arch"
            KERNEL["repo"] = False
            GREETER["name"] = ""
            pacstrap(fallback_packages(pkgs))
        configure(cfg, root, uefi)
        finish()
        emit(progress=1.0, status="Fiordland is installed", done=True)
    except Exception as e:
        log(f"error: {e}")
        tail = getattr(e, "tail", [])
        try:
            release_mnt()
        except Exception as ce:
            log(f"cleanup: {ce}")
        emit(error=str(e), detail="\n".join(tail))
        sys.exit(1)


if __name__ == "__main__":
    main()

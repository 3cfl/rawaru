import os
import re
import stat
import subprocess

import desktops

BOOTMNT = "/run/archiso/bootmnt"

USERNAME_RE = re.compile(r"[a-z_][a-z0-9_-]{0,31}")
HOSTNAME_RE = re.compile(r"[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?")
DISK_RE = re.compile(r"/dev/(sd[a-z]{1,2}|vd[a-z]{1,2}|xvd[a-z]{1,2}|hd[a-z]{1,2}|nvme\d{1,3}n\d{1,3}|mmcblk\d{1,3})")
KEYMAP_RE = re.compile(r"[a-z][a-z0-9_-]{0,15}")
LOCALE_RE = re.compile(r"[a-zA-Z]{1,3}(_[A-Za-z0-9]{2,3})?(@[a-z]+)?\.UTF-8(@[a-z]+)?")
TIMEZONE_RE = re.compile(r"UTC|[A-Z][A-Za-z_+-]{1,30}(/[A-Za-z0-9_+-]{1,30}){1,2}")
SERVER_RE = re.compile(r"https://[A-Za-z0-9.-]{1,253}(:\d{1,5})?(/[A-Za-z0-9._~$%/-]{0,512})?")

RESERVED = {
    "root", "bin", "daemon", "mail", "ftp", "http", "nobody", "dbus", "systemd-network", "systemd-resolve",
    "systemd-timesync", "systemd-coredump", "systemd-oom", "systemd-journal-remote", "uuidd", "greeter", "polkitd",
    "rtkit", "git", "avahi", "sddm", "gdm", "lightdm", "colord", "cups", "geoclue", "flatpak", "usbmux", "nm-openvpn",
    "alpm", "tss", "dnsmasq", "qemu", "brltty", "saned", "named", "rpc", "ntp", "fwupd", "wheel", "users", "adm",
}

MODES = ("erase", "alongside", "manual")
KERNELS = ("cachyos", "arch", "fiord")
CHANNELS = ("stable", "rolling")
GREETERS = ("", "crest")
MAX_PASSWORD = 512


class ConfigError(ValueError):
    pass


def username_error(name):
    if not name:
        return "Choose a username"
    if not USERNAME_RE.fullmatch(name):
        return "Lowercase letters, numbers, - and _ only"
    if name in RESERVED:
        return "That name is used by the system"
    return ""


def hostname_error(name):
    if not name:
        return "Choose a computer name"
    if not HOSTNAME_RE.fullmatch(name):
        return "Letters, numbers and dashes only"
    return ""


def password_error(pw):
    if not pw:
        return "Choose a password"
    if len(pw) > MAX_PASSWORD:
        return "That password is too long"
    if any(c in pw for c in "\n\r\0"):
        return "Passwords can't contain line breaks"
    return ""


def fullname_error(name):
    if len(name) > 128:
        return "That name is too long"
    if any(c in name for c in ":,\n\r\0\\"):
        return "Names can't contain : , or line breaks"
    return ""


def disk_error(path):
    if not isinstance(path, str) or not DISK_RE.fullmatch(path):
        return "Not a disk device"
    return ""


def partition_error(disk, part):
    if disk_error(disk):
        return "Not a disk device"
    sep = "p" if disk[-1].isdigit() else ""
    if not isinstance(part, str) or not re.fullmatch(re.escape(disk) + sep + r"[1-9]\d{0,2}", part):
        return "That partition is not on the chosen disk"
    return ""


def partition_name(disk, n):
    return f"{disk}p{n}" if disk[-1].isdigit() else f"{disk}{n}"


def keymap_error(code):
    return "" if isinstance(code, str) and KEYMAP_RE.fullmatch(code) else "Unknown keyboard layout"


def locale_error(code):
    return "" if isinstance(code, str) and LOCALE_RE.fullmatch(code) else "Unknown language"


def timezone_error(zone):
    if not isinstance(zone, str) or not TIMEZONE_RE.fullmatch(zone) or ".." in zone:
        return "Unknown time zone"
    return ""


def server_error(url):
    return "" if isinstance(url, str) and SERVER_RE.fullmatch(url) and ".." not in url else "Bad mirror address"


def _text(cfg, key, default=""):
    v = cfg.get(key, default)
    if v is None:
        v = default
    if not isinstance(v, str):
        raise ConfigError(f"{key} must be text")
    return v


def _need(err):
    if err:
        raise ConfigError(err)


def validate_config(cfg):
    if not isinstance(cfg, dict):
        raise ConfigError("The install settings are not valid")
    out = {}
    out["disk"] = _text(cfg, "disk")
    _need(disk_error(out["disk"]))
    out["mode"] = _text(cfg, "mode", "erase") or "erase"
    if out["mode"] not in MODES:
        raise ConfigError("Unknown disk mode")
    out["username"] = _text(cfg, "username")
    _need(username_error(out["username"]))
    out["hostname"] = _text(cfg, "hostname", "fiordland") or "fiordland"
    _need(hostname_error(out["hostname"]))
    out["password"] = _text(cfg, "password")
    _need(password_error(out["password"]))
    out["fullname"] = _text(cfg, "fullname").strip()
    _need(fullname_error(out["fullname"]))
    out["locale"] = _text(cfg, "locale", "en_US.UTF-8") or "en_US.UTF-8"
    _need(locale_error(out["locale"]))
    out["keymap"] = _text(cfg, "keymap", "us") or "us"
    _need(keymap_error(out["keymap"]))
    out["timezone"] = _text(cfg, "timezone", "UTC") or "UTC"
    _need(timezone_error(out["timezone"]))
    out["desktop"] = _text(cfg, "desktop", "plasma") or "plasma"
    if not any(d["id"] == out["desktop"] for d in desktops.DESKTOPS):
        raise ConfigError("Unknown desktop")
    shell = _text(cfg, "shell") or None
    d, resolved = desktops.resolve(out["desktop"], shell)
    if shell and shell not in d.get("shells", []):
        raise ConfigError("That shell does not go with this desktop")
    out["shell"] = resolved
    out["kernel"] = _text(cfg, "kernel", "cachyos") or "cachyos"
    if out["kernel"] not in KERNELS:
        raise ConfigError("Unknown kernel")
    out["channel"] = _text(cfg, "channel")
    if out["channel"] and out["channel"] not in CHANNELS:
        raise ConfigError("Unknown update channel")
    out["stable_server"] = _text(cfg, "stable_server")
    if out["stable_server"]:
        _need(server_error(out["stable_server"]))
    out["greeter"] = _text(cfg, "greeter")
    if out["greeter"] not in GREETERS:
        raise ConfigError("Unknown login screen")
    if out["greeter"] and not (d["id"] == "hyprland" and resolved == "crest"):
        out["greeter"] = ""
    for key in ("autologin", "lowend"):
        v = cfg.get(key, False)
        if not isinstance(v, bool):
            raise ConfigError(f"{key} must be true or false")
        out[key] = v
    out["root"] = out["esp"] = out["shrink"] = ""
    out["size"] = 0
    if out["mode"] == "manual":
        out["root"] = _text(cfg, "root")
        _need(partition_error(out["disk"], out["root"]))
        out["esp"] = _text(cfg, "esp")
        if out["esp"]:
            _need(partition_error(out["disk"], out["esp"]))
            if out["esp"] == out["root"]:
                raise ConfigError("The boot partition and the Fiordland partition must differ")
    elif out["mode"] == "alongside":
        out["shrink"] = _text(cfg, "shrink")
        if out["shrink"]:
            _need(partition_error(out["disk"], out["shrink"]))
        size = cfg.get("size", 0)
        if isinstance(size, float) and size.is_integer():
            size = int(size)
        if not isinstance(size, int) or isinstance(size, bool) or size < 0:
            raise ConfigError("Bad size for the Fiordland partition")
        out["size"] = size
    disk_size = cfg.get("disk_size", 0)
    if isinstance(disk_size, float) and disk_size.is_integer():
        disk_size = int(disk_size)
    if not isinstance(disk_size, int) or isinstance(disk_size, bool) or disk_size < 0:
        raise ConfigError("Bad disk size")
    out["disk_size"] = disk_size
    return out


def boot_disk(run=subprocess.run):
    try:
        src = run(["findmnt", "-no", "SOURCE", BOOTMNT], capture_output=True, text=True, timeout=10).stdout.strip()
        if not src:
            return ""
        pk = run(["lsblk", "-no", "PKNAME", src], capture_output=True, text=True, timeout=10).stdout.strip()
        return "/dev/" + pk.splitlines()[0] if pk else src
    except (OSError, subprocess.SubprocessError):
        return ""


def check_target(disk, size=0, run=subprocess.run):
    _need(disk_error(disk))
    if os.path.realpath(disk) != disk:
        raise ConfigError(f"{disk} is a link, not a disk")
    try:
        mode = os.stat(disk).st_mode
    except OSError:
        raise ConfigError(f"{disk} is gone. Go back and choose the disk again") from None
    if not stat.S_ISBLK(mode):
        raise ConfigError(f"{disk} is not a block device")
    p = run(["lsblk", "-dnbpo", "TYPE,RO,SIZE", disk], capture_output=True, text=True, timeout=30)
    bits = p.stdout.split()
    if p.returncode != 0 or len(bits) != 3:
        raise ConfigError(f"Could not read {disk}")
    kind, ro, real_size = bits
    if kind != "disk":
        raise ConfigError(f"{disk} is not a whole disk")
    if ro != "0":
        raise ConfigError(f"{disk} is read-only")
    if size and int(real_size) != size:
        raise ConfigError(f"{disk} changed since you picked it. Go back and choose the disk again")
    if disk == boot_disk(run):
        raise ConfigError("That is the disk Fiordland was started from")
    p = run(["lsblk", "-lnpo", "MOUNTPOINTS", disk], capture_output=True, text=True, timeout=30)
    for mp in p.stdout.split():
        if mp == "/" or mp.startswith("/run/archiso"):
            raise ConfigError("That disk holds the running live system")
    return True


def check_partition(disk, part, run=subprocess.run):
    _need(partition_error(disk, part))
    p = run(["lsblk", "-no", "PKNAME", part], capture_output=True, text=True, timeout=30)
    parent = p.stdout.strip().splitlines()
    if p.returncode != 0 or not parent or "/dev/" + parent[0] != disk:
        raise ConfigError(f"{part} is not on {disk}")
    return True

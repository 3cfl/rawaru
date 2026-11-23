import json
import os
import re
import subprocess
import tempfile
import threading
import urllib.request

from PySide6.QtCore import Property, QObject, QProcess, QTimer, Signal, Slot

HERE = os.path.dirname(os.path.abspath(__file__))
BOOTMNT = "/run/archiso/bootmnt"
MIN_SIZE = 20 * 1000**3


def human(n):
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if n < 1000 or unit == "TB":
            return f"{n:.0f} {unit}" if unit in ("B", "KB") else f"{n:.1f} {unit}".replace(".0 ", " ")
        n /= 1000
    return str(n)


def read_locales():
    out = []
    try:
        with open("/usr/share/i18n/SUPPORTED") as f:
            for line in f:
                name, _, charset = line.strip().partition(" ")
                if charset == "UTF-8" and name.endswith(".UTF-8"):
                    out.append(name)
    except OSError:
        out = ["en_US.UTF-8"]
    return out


def read_keymaps():
    out = []
    try:
        with open("/usr/share/X11/xkb/rules/base.lst") as f:
            section = None
            for line in f:
                if line.startswith("!"):
                    section = line[1:].strip()
                    continue
                if section == "layout" and line.strip():
                    code, desc = line.strip().split(None, 1)
                    out.append({"code": code, "name": desc})
    except OSError:
        out = [{"code": "us", "name": "English (US)"}]
    out.sort(key=lambda k: k["name"].lower())
    return out


def read_timezones():
    zones = []
    try:
        with open("/usr/share/zoneinfo/tzdata.zi") as f:
            for line in f:
                if line.startswith("Z "):
                    zones.append(line.split()[1])
                elif line.startswith("L "):
                    zones.append(line.split()[2])
    except OSError:
        pass
    keep = ("Africa", "America", "Antarctica", "Asia", "Atlantic", "Australia", "Europe", "Indian", "Pacific")
    zones = sorted({z for z in zones if z.split("/")[0] in keep and "/" in z})
    return ["UTC"] + zones


def boot_disk():
    try:
        src = subprocess.run(["findmnt", "-no", "SOURCE", BOOTMNT], capture_output=True, text=True).stdout.strip()
        if not src:
            return ""
        pk = subprocess.run(["lsblk", "-no", "PKNAME", src], capture_output=True, text=True).stdout.strip()
        return "/dev/" + pk.splitlines()[0] if pk else src
    except Exception:
        return ""


def read_disks():
    try:
        out = subprocess.run(
            ["lsblk", "-J", "-b", "-o", "NAME,PATH,SIZE,MODEL,TYPE,TRAN,RM,RO,VENDOR"],
            capture_output=True, text=True, check=True,
        ).stdout
        devs = json.loads(out).get("blockdevices", [])
    except Exception:
        devs = []
    skip = boot_disk()
    disks = []
    for d in devs:
        if d.get("type") != "disk" or d.get("ro") or d.get("path") == skip:
            continue
        if re.match(r"(loop|zram|sr|ram)", d.get("name", "")):
            continue
        size = int(d.get("size") or 0)
        vendor = (d.get("vendor") or "").strip()
        if re.fullmatch(r"0x[0-9a-fA-F]+|ATA", vendor):
            vendor = ""
        tran = (d.get("tran") or "").lower()
        model = " ".join(filter(None, [vendor, (d.get("model") or "").strip()]))
        if not model:
            model = "Virtual disk" if d.get("name", "").startswith(("vd", "xvd")) else "Disk"
        kind = "usb" if tran == "usb" or d.get("rm") else "nvme" if tran == "nvme" or "nvme" in d["name"] else "disk"
        disks.append({
            "path": d["path"], "model": model, "size": size, "sizeText": human(size),
            "kind": kind, "big": size >= MIN_SIZE,
            "parts": len(d.get("children") or []),
        })
    return disks


class Backend(QObject):
    progressChanged = Signal()
    statusChanged = Signal()
    logAdded = Signal(str)
    installFinished = Signal(bool, str)
    timezoneGuessed = Signal(str)
    disksChanged = Signal()

    def __init__(self, dry_run=False):
        super().__init__()
        self._dry = dry_run
        self._progress = 0.0
        self._status = ""
        self._buf = b""
        self._locales = read_locales()
        self._keymaps = read_keymaps()
        self._timezones = read_timezones()
        self._disks = read_disks()
        if dry_run and not self._disks:
            self._disks = [{"path": "/dev/vda", "model": "Virtual disk", "size": 32 * 1000**3,
                            "sizeText": "32 GB", "kind": "disk", "big": True, "parts": 0}]
        self._proc = None
        self._error = ""
        self._done = False
        self._log = []

    @Property(bool, constant=True)
    def dryRun(self):
        return self._dry

    @Property(bool, constant=True)
    def uefi(self):
        return os.path.isdir("/sys/firmware/efi")

    @Property("QVariantList", constant=True)
    def locales(self):
        return self._locales

    @Property("QVariantList", constant=True)
    def keymaps(self):
        return self._keymaps

    @Property("QVariantList", constant=True)
    def timezones(self):
        return self._timezones

    @Property("QVariantList", notify=disksChanged)
    def disks(self):
        return self._disks

    @Property(float, notify=progressChanged)
    def progress(self):
        return self._progress

    @Property(str, notify=statusChanged)
    def status(self):
        return self._status

    @Property(str, constant=True)
    def wallpaper(self):
        for p in ("/usr/share/fiordland/wallpaper.png",
                  os.path.join(HERE, "..", "packages", "fiordland-desktop", "files", "wallpaper.png")):
            if os.path.isfile(p):
                return "file://" + os.path.abspath(p)
        return ""

    @Slot()
    def refreshDisks(self):
        self._disks = read_disks() or self._disks
        self.disksChanged.emit()

    @Slot()
    def guessTimezone(self):
        def work():
            tz = ""
            try:
                with urllib.request.urlopen("https://geoip.kde.org/v1/calamares", timeout=3) as r:
                    tz = json.load(r).get("time_zone", "")
            except Exception:
                tz = ""
            if not tz:
                try:
                    tz = os.path.realpath("/etc/localtime").split("zoneinfo/", 1)[1]
                except Exception:
                    tz = ""
            if tz in self._timezones:
                self.timezoneGuessed.emit(tz)
        threading.Thread(target=work, daemon=True).start()

    @Slot(str)
    def setKeymap(self, code):
        if self._dry:
            return
        subprocess.Popen(["hyprctl", "keyword", "input:kb_layout", code],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    @Slot("QVariantMap")
    def install(self, cfg):
        if self._proc:
            return
        fd, path = tempfile.mkstemp(prefix="rawaru-", suffix=".json")
        with os.fdopen(fd, "w") as f:
            json.dump(dict(cfg), f)
        os.chmod(path, 0o600)
        engine = os.path.join(HERE, "engine.py")
        self._proc = QProcess(self)
        self._proc.setProcessChannelMode(QProcess.MergedChannels)
        self._proc.readyReadStandardOutput.connect(self._read)
        self._proc.finished.connect(self._exited)
        if self._dry:
            self._proc.start("python3", [engine, "--dry-run", path])
        else:
            self._proc.start("sudo", ["-n", "python3", engine, path])

    def _read(self):
        self._buf += bytes(self._proc.readAllStandardOutput())
        *lines, self._buf = self._buf.split(b"\n")
        for raw in lines:
            line = raw.decode(errors="replace").strip()
            if not line:
                continue
            try:
                msg = json.loads(line)
            except ValueError:
                self._log.append(line)
                self.logAdded.emit(line)
                continue
            if "progress" in msg:
                self._progress = float(msg["progress"])
                self.progressChanged.emit()
            if "status" in msg:
                self._status = msg["status"]
                self.statusChanged.emit()
            if "log" in msg:
                self._log.append(msg["log"])
                self.logAdded.emit(msg["log"])
            if msg.get("done"):
                self._done = True
            if "error" in msg:
                self._error = msg["error"]

    def _exited(self, code, _status):
        self._read()
        ok = self._done and code == 0
        err = "" if ok else (self._error or f"The installer stopped unexpectedly (code {code}).")
        self._proc = None
        QTimer.singleShot(400, lambda: self.installFinished.emit(ok, err))

    @Slot()
    def saveLog(self):
        with open(os.path.expanduser("~/rawaru.log"), "w") as f:
            f.write("\n".join(self._log) + "\n")

    @Slot()
    def reboot(self):
        if self._dry:
            print("reboot")
            return
        subprocess.Popen(["systemctl", "reboot"])

    @Slot()
    def quit(self):
        from PySide6.QtGui import QGuiApplication
        QGuiApplication.quit()

import glob
import json
import os
import re
import shutil
import subprocess
import threading
import time
import urllib.request

from PySide6.QtCore import Property, QObject, QProcess, QTimer, Signal, Slot

import checks
import desktops

HERE = os.path.dirname(os.path.abspath(__file__))
BOOTMNT = checks.BOOTMNT
MIN_SIZE = 20 * 1000**3
LOCAL_REPO = "/opt/fiordland/repo"
LOW_RAM_KB = 3_400_000
SOFTWARE_GL = ("llvmpipe", "softpipe", "swrast", "software rasterizer", "lavapipe")


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
                if charset == "UTF-8" and name.endswith(".UTF-8") and not checks.locale_error(name):
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
                    if not checks.keymap_error(code):
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
    zones = sorted({z for z in zones if z.split("/")[0] in keep and "/" in z and not checks.timezone_error(z)})
    return ["UTC"] + zones


def boot_disk():
    return checks.boot_disk()


def read_disks():
    try:
        out = subprocess.run(
            ["lsblk", "-J", "-b", "-o", "NAME,PATH,SIZE,MODEL,TYPE,TRAN,RM,RO,VENDOR"],
            capture_output=True, text=True, check=True, timeout=30,
        ).stdout
        devs = json.loads(out).get("blockdevices", [])
    except (OSError, ValueError, subprocess.SubprocessError):
        devs = []
    skip = boot_disk()
    disks = []
    for d in devs:
        if d.get("type") != "disk" or d.get("ro") or d.get("path") == skip:
            continue
        if checks.disk_error(d.get("path") or ""):
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


def ram_kb():
    try:
        with open("/proc/meminfo") as f:
            for line in f:
                if line.startswith("MemTotal:"):
                    return int(line.split()[1])
    except (OSError, ValueError, IndexError):
        pass
    return 0


def gl_renderer():
    if os.environ.get("QT_QPA_PLATFORM") == "offscreen" or os.environ.get("QT_QUICK_BACKEND") == "software":
        return ""
    try:
        from PySide6.QtGui import QOffscreenSurface, QOpenGLContext
        ctx = QOpenGLContext()
        if not ctx.create():
            return ""
        surface = QOffscreenSurface()
        surface.setFormat(ctx.format())
        surface.create()
        if not ctx.makeCurrent(surface):
            return ""
        name = ctx.functions().glGetString(0x1F01)
        ctx.doneCurrent()
        return str(name or "")
    except Exception:
        return ""


def detect_low_end(env=None, ram=None, renderer=None):
    env = os.environ if env is None else env
    forced = env.get("RAWARU_LOW_END", "")
    if forced in ("0", "1"):
        return forced == "1"
    if env.get("QT_QUICK_BACKEND") == "software":
        return True
    ram = ram_kb() if ram is None else ram
    if 0 < ram < LOW_RAM_KB:
        return True
    renderer = gl_renderer() if renderer is None else renderer
    return any(s in renderer.lower() for s in SOFTWARE_GL)


def package_available(name, run=subprocess.run):
    if not re.fullmatch(r"[a-z0-9@_+][a-z0-9@._+-]*", name):
        return False
    try:
        if run(["pacman", "-Si", "--", name], capture_output=True, text=True, timeout=20).returncode == 0:
            return True
    except (OSError, subprocess.SubprocessError):
        pass
    return bool(glob.glob(os.path.join(LOCAL_REPO, f"{name}-[0-9]*.pkg.tar.*")))


def private_log_path():
    return os.path.expanduser("~/rawaru.log")


def write_private(path, text):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w") as f:
        os.fchmod(f.fileno(), 0o600)
        f.write(text)


def engine_command(engine, dry):
    if dry:
        return "python3", [engine, "--dry-run", "-"]
    return "sudo", ["-n", "python3", engine, "-"]


class Backend(QObject):
    progressChanged = Signal()
    statusChanged = Signal()
    logAdded = Signal(str)
    installFinished = Signal(bool, str, str)
    timezoneGuessed = Signal(str)
    disksChanged = Signal()
    probed = Signal(str, "QVariantMap")
    editorClosed = Signal()
    optionsChanged = Signal()

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
        self._detail = ""
        self._done = False
        self._log = []
        self._low_end = detect_low_end()
        self._fiord_kernel = False
        self._crest_greeter = False

    @Property(bool, constant=True)
    def dryRun(self):
        return self._dry

    @Property(bool, constant=True)
    def uefi(self):
        return os.path.isdir("/sys/firmware/efi")

    @Property(bool, constant=True)
    def lowEnd(self):
        return self._low_end

    @Property(int, constant=True)
    def ramGb(self):
        return round(ram_kb() / 1024 / 1024)

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
    def graphics(self):
        try:
            from engine import gpus
            found = gpus()
        except Exception:
            found = []
        names = {"0x8086": "Intel", "0x1002": "AMD"}
        parts = [names[v] for v in sorted({v for v, _ in found}) if v in names]
        nv = [d for v, d in found if v == "0x10de"]
        if nv:
            parts.append("NVIDIA, proprietary driver" if max(nv) >= 0x1e00 else "NVIDIA, open nouveau driver")
        return " + ".join(parts) if parts else "Generic, Mesa drivers"

    @Property("QVariantList", constant=True)
    def desktops(self):
        return desktops.catalogue()

    @Property(str, constant=True)
    def defaultDesktop(self):
        try:
            with open("/etc/rawaru/default-desktop") as f:
                d = f.read().strip()
        except OSError:
            d = os.environ.get("RAWARU_DESKTOP", "")
        return d if any(x["id"] == d for x in desktops.DESKTOPS) else "plasma"

    @Property(str, constant=True)
    def lightDesktop(self):
        return desktops.LIGHT_DEFAULT

    @Property(str, constant=True)
    def wallpaper(self):
        for p in (os.environ.get("RAWARU_WALLPAPER", ""), "/usr/share/fiordland/wallpaper.png",
                  os.path.join(HERE, "..", "packages", "fiordland-desktop", "files", "wallpaper.png")):
            if p and os.path.isfile(p):
                return "file://" + os.path.abspath(p)
        return ""

    @Property(bool, notify=optionsChanged)
    def fiordKernel(self):
        return self._fiord_kernel

    @Property(bool, notify=optionsChanged)
    def crestGreeter(self):
        return self._crest_greeter

    @Slot()
    def detectOptions(self):
        def work():
            if self._dry:
                fiord = os.environ.get("RAWARU_FAKE_FIORD") == "1"
                greeter = fiord
            else:
                fiord = package_available("linux-fiord")
                greeter = package_available("crest-greeter")
            self._fiord_kernel, self._crest_greeter = fiord, greeter
            self.optionsChanged.emit()
        threading.Thread(target=work, daemon=True).start()

    @Slot(str, result=str)
    def usernameError(self, name):
        return checks.username_error(name) if name else ""

    @Slot(str, result=str)
    def hostnameError(self, name):
        return checks.hostname_error(name) if name else ""

    @Slot(str, result=str)
    def fullnameError(self, name):
        return checks.fullname_error(name)

    @Slot(str, result=str)
    def passwordError(self, pw):
        return checks.password_error(pw) if pw else ""

    def _known_disk(self, disk):
        return any(d["path"] == disk for d in self._disks)

    @Slot(str)
    def probe(self, disk):
        if not self._known_disk(disk) or checks.disk_error(disk):
            self.probed.emit(disk, {"disk": disk, "options": [], "notes": ["That disk is not available."]})
            return

        def work():
            if self._dry:
                time.sleep(0.6)
                res = {"disk": disk, "uefi": True, "gpt": True, "esp": disk + "1", "system": "Windows", "notes": [],
                       "options": [{"kind": "shrink", "part": disk + "3", "label": "Windows", "max": 180 * 1000**3,
                                    "min": 20 * 1000**3, "partSize": 240 * 1000**3}],
                       "parts": [{"node": disk + "1", "size": 100 * 1000**2, "fs": "vfat", "label": "EFI", "esp": True,
                                  "biosBoot": False, "usable": False},
                                 {"node": disk + "2", "size": 16 * 1000**2, "fs": "", "label": "", "esp": False,
                                  "biosBoot": False, "usable": False},
                                 {"node": disk + "3", "size": 240 * 1000**3, "fs": "ntfs", "label": "Windows",
                                  "esp": False, "biosBoot": False, "usable": True},
                                 {"node": disk + "4", "size": 60 * 1000**3, "fs": "ext4", "label": "data",
                                  "esp": False, "biosBoot": False, "usable": True}]}
            else:
                try:
                    out = subprocess.run(["sudo", "-n", "python3", os.path.join(HERE, "engine.py"), "--probe", disk],
                                         capture_output=True, text=True, timeout=600).stdout
                    res = json.loads(out.strip().splitlines()[-1])
                except Exception as e:
                    res = {"disk": disk, "options": [], "notes": [f"Could not inspect this disk: {e}"]}
            self.probed.emit(disk, res)
        threading.Thread(target=work, daemon=True).start()

    def _editor(self):
        return next((e for e in ("partitionmanager", "gparted") if shutil.which(e)), None)

    @Slot(result=bool)
    def hasPartitionEditor(self):
        return self._dry or self._editor() is not None

    @Slot()
    def openPartitionEditor(self):
        def work():
            editor = self._editor()
            if not self._dry and editor:
                try:
                    subprocess.run([editor], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                except OSError:
                    pass
            self.editorClosed.emit()
        threading.Thread(target=work, daemon=True).start()

    @Slot()
    def refreshDisks(self):
        self._disks = read_disks() or self._disks
        self.disksChanged.emit()

    @Slot()
    def guessTimezone(self):
        def work():
            for _ in range(36):
                try:
                    with urllib.request.urlopen("https://geoip.kde.org/v1/calamares", timeout=4) as r:
                        tz = json.loads(r.read(4096)).get("time_zone", "")
                except Exception:
                    tz = ""
                if tz in self._timezones:
                    self.timezoneGuessed.emit(tz)
                    return
                time.sleep(5)
            try:
                tz = os.path.realpath("/etc/localtime").split("zoneinfo/", 1)[1]
            except Exception:
                tz = ""
            if tz in self._timezones and tz != "UTC":
                self.timezoneGuessed.emit(tz)
        if not self._dry:
            threading.Thread(target=work, daemon=True).start()

    @Slot(str)
    def setKeymap(self, code):
        if self._dry or checks.keymap_error(code):
            return
        quiet = {"stdout": subprocess.DEVNULL, "stderr": subprocess.DEVNULL}
        try:
            if os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
                subprocess.Popen(["hyprctl", "keyword", "input:kb_layout", code], **quiet)
            elif "KDE" in os.environ.get("XDG_CURRENT_DESKTOP", ""):
                subprocess.run(["kwriteconfig6", "--file", "kxkbrc", "--group", "Layout", "--key", "LayoutList", code], **quiet)
                subprocess.run(["kwriteconfig6", "--file", "kxkbrc", "--group", "Layout", "--key", "Use", "--type", "bool", "true"], **quiet)
                subprocess.Popen(["dbus-send", "--session", "--type=signal", "/Layouts", "org.kde.keyboard.reloadConfig"], **quiet)
        except OSError:
            pass

    def _fail(self, err):
        self._proc = None
        QTimer.singleShot(0, lambda: self.installFinished.emit(False, err, ""))

    @Slot("QVariantMap")
    def install(self, cfg):
        if self._proc:
            return
        self._error = ""
        self._detail = ""
        self._done = False
        self._log = []
        self._buf = b""
        try:
            clean = checks.validate_config(dict(cfg))
        except checks.ConfigError as e:
            self._fail(str(e))
            return
        if not self._known_disk(clean["disk"]):
            self._fail("That disk is not available any more. Go back and choose it again.")
            return
        if clean["kernel"] == "fiord" and not self._fiord_kernel:
            clean["kernel"] = "cachyos"
        if clean["greeter"] and not self._crest_greeter:
            clean["greeter"] = ""
        payload = json.dumps(clean).encode()
        clean.clear()
        program, args = engine_command(os.path.join(HERE, "engine.py"), self._dry)
        self._proc = QProcess(self)
        self._proc.setProcessChannelMode(QProcess.MergedChannels)
        self._proc.readyReadStandardOutput.connect(self._read)
        self._proc.finished.connect(self._exited)
        self._proc.start(program, args)
        if not self._proc.waitForStarted(10000):
            self._proc = None
            self._fail("Could not start the installer engine.")
            return
        self._proc.write(payload)
        self._proc.closeWriteChannel()

    def _read(self):
        self._buf += bytes(self._proc.readAllStandardOutput())
        *lines, self._buf = self._buf.split(b"\n")
        for raw in lines:
            self._line(raw.decode(errors="replace").strip())

    def _line(self, line):
        if not line:
            return
        try:
            msg = json.loads(line)
        except ValueError:
            msg = None
        if not isinstance(msg, dict):
            self._log.append(line)
            self.logAdded.emit(line)
            return
        if "progress" in msg:
            self._progress = float(msg["progress"])
            self.progressChanged.emit()
        if "status" in msg:
            self._status = str(msg["status"])
            self.statusChanged.emit()
        if "log" in msg:
            self._log.append(str(msg["log"]))
            self.logAdded.emit(str(msg["log"]))
        if msg.get("done"):
            self._done = True
        if "error" in msg:
            self._error = str(msg["error"])
            self._detail = str(msg.get("detail", ""))

    def _exited(self, code, _status):
        self._read()
        ok = self._done and code == 0
        err = "" if ok else (self._error or f"The installer stopped unexpectedly (code {code}).")
        detail = "" if ok else (self._detail or "\n".join(self._log[-20:]))
        self._proc = None
        if not ok:
            try:
                self.saveLog()
            except OSError:
                pass
        QTimer.singleShot(400, lambda: self.installFinished.emit(ok, err, detail))

    @Slot()
    def saveLog(self):
        write_private(private_log_path(), "\n".join(self._log) + "\n")

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

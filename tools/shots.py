#!/usr/bin/env python3
import argparse
import os
import sys
import threading
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")
os.environ.setdefault("RAWARU_LOW_END", "0")
os.environ.setdefault("RAWARU_FAKE_FIORD", "1")

DISKS = [
    {"path": "/dev/nvme0n1", "model": "Samsung SSD 980 PRO", "size": 1000204886016, "sizeText": "1 TB",
     "kind": "nvme", "big": True, "parts": 4},
    {"path": "/dev/sda", "model": "Crucial MX500", "size": 500107862016, "sizeText": "500 GB",
     "kind": "disk", "big": True, "parts": 0},
    {"path": "/dev/sdb", "model": "SanDisk Ultra", "size": 15376000000, "sizeText": "15 GB",
     "kind": "usb", "big": False, "parts": 1},
]

LOG = [
    ":: Synchronizing package databases...",
    " core downloading...",
    " extra downloading...",
    "resolving dependencies...",
    "looking for conflicting packages...",
    "Packages (412) base-3-2 linux-cachyos-6.17.9-1 mesa-1:25.2.7-1 pipewire-1:1.4.9-1",
    "(124/412) installing systemd",
    "(125/412) installing pipewire",
    "(126/412) installing mesa",
    "(127/412) installing plasma-desktop",
]


def pump(app, seconds):
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        app.processEvents()
        time.sleep(0.01)


SCENES = [
    ("01-welcome", "step = 0"),
    ("02-region", "step = 1"),
    ("03-language", "step = 1; openLanguage()"),
    ("04-disk-erase", "closePopups(); step = 2; pickDisk('/dev/nvme0n1'); pickOption(-1); understood = true"),
    ("05-disk-alongside", "pickOption(0); understood = true"),
    ("06-disk-manual", "pickManual()"),
    ("07-account", "pickOption(-1); understood = true; step = 3; fullname = 'Aroha Ngata';"
                   " password = 'correct horse'; password2 = 'correct horse'"),
    ("08-account-errors", "usernameTouched = true; username = 'Root!'; hostname = 'my_pc'; password2 = 'correct hose'"),
    ("09-desktop", "username = 'aroha'; hostname = 'fiordland'; password2 = 'correct horse'; step = 4"),
    ("10-desktop-wm", "wmTab = true; pickDesktop(desktopInfo('hyprland'))"),
    ("11-desktop-lowend", "wmTab = false; desktopTouched = false; setLowEnd(true)"),
    ("12-summary", "setLowEnd(false); step = 5"),
    ("13-summary-crest", "pickDesktop(desktopInfo('hyprland')); greeter = 'crest'; kernel = 'fiord'"),
    ("14-confirm", "next()"),
    ("15-progress", "closePopups(); step = 6"),
    ("16-progress-log", "logOpen = true"),
    ("17-done", "logOpen = false; failed = false; step = 7"),
    ("18-failed", "failed = true; errorText = 'Could not download packages. Check the network cable or Wi-Fi and try again.';"
                  " errorDetail = 'error: failed retrieving file mesa-1:25.2.7-1 from mirror : Connection timed out\n"
                  "error: failed to commit transaction (failed to retrieve some files)'; step = 7"),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="shots")
    ap.add_argument("--size", default="1024x768")
    ap.add_argument("--prefix", default="")
    ap.add_argument("--only", default="")
    ap.add_argument("--settle", type=float, default=1.6)
    ap.add_argument("--timeout", type=float, default=300)
    args = ap.parse_args()

    killer = threading.Timer(args.timeout, lambda: os._exit(3))
    killer.daemon = True
    killer.start()

    from PySide6.QtCore import Qt
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQml import QQmlExpression
    from PySide6.QtQuickControls2 import QQuickStyle

    import rawaru
    from backend import Backend

    QGuiApplication.setHighDpiScaleFactorRoundingPolicy(Qt.HighDpiScaleFactorRoundingPolicy.PassThrough)
    QQuickStyle.setStyle("Basic")
    app = QGuiApplication(sys.argv[:1])
    backend = Backend(dry_run=True)
    backend._disks = [dict(d) for d in DISKS]
    engine = rawaru.build(backend)
    roots = engine.rootObjects()
    if not roots:
        print("Main.qml failed to load", file=sys.stderr)
        os._exit(2)
    win = roots[0]
    w, h = (int(x) for x in args.size.split("x"))
    win.setProperty("minimumWidth", min(w, 900))
    win.setProperty("minimumHeight", min(h, 640))
    win.setWidth(w)
    win.setHeight(h)
    os.makedirs(args.out, exist_ok=True)
    pump(app, 2.0)
    only = [s for s in args.only.split(",") if s]
    failures = 0
    context = engine.contextForObject(win)
    for name, script in SCENES:
        keep = not only or name in only
        if name == "15-progress":
            backend._line('{"progress": 0.52, "status": "Installing packages"}')
            for line in LOG:
                backend._line(line)
        expr = QQmlExpression(context, win, script)
        expr.evaluate()
        if expr.hasError():
            print(f"{name}: {expr.error().toString()}", file=sys.stderr)
            failures += 1
            continue
        pump(app, args.settle if keep else 0.8)
        if not keep:
            continue
        img = win.grabWindow()
        path = os.path.join(args.out, f"{args.prefix}{name}.png")
        if img.isNull() or not img.save(path):
            print(f"{name}: grab failed", file=sys.stderr)
            failures += 1
        else:
            print(path, img.width(), img.height())
    sys.stdout.flush()
    os._exit(1 if failures else 0)


if __name__ == "__main__":
    main()

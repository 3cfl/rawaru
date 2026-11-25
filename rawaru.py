#!/usr/bin/env python3
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PySide6.QtCore import Qt, QUrl
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle

from backend import HERE, Backend


def build(backend):
    engine = QQmlApplicationEngine()
    engine.setInitialProperties({"backend": backend})
    engine.load(QUrl.fromLocalFile(os.path.join(HERE, "qml", "Main.qml")))
    return engine


def main():
    dry = "--dry-run" in sys.argv or os.environ.get("RAWARU_DRY") == "1"
    QGuiApplication.setHighDpiScaleFactorRoundingPolicy(Qt.HighDpiScaleFactorRoundingPolicy.PassThrough)
    QQuickStyle.setStyle("Basic")
    app = QGuiApplication(sys.argv)
    app.setApplicationName("rawaru")
    app.setApplicationDisplayName("Install Fiordland")
    app.setDesktopFileName("rawaru")
    app.setWindowIcon(QIcon.fromTheme("system-software-install"))
    backend = Backend(dry_run=dry)
    engine = build(backend)
    if not engine.rootObjects():
        sys.exit(1)
    sys.exit(app.exec())


if __name__ == "__main__":
    main()

import json
import os
import stat
import subprocess

import pytest

pytest.importorskip("PySide6")

import backend


class Signal:
    def connect(self, fn):
        self.fn = fn


class FakeProcess:
    MergedChannels = 1
    started = []

    def __init__(self, parent=None):
        self.readyReadStandardOutput = Signal()
        self.finished = Signal()
        self.stdin = b""
        self.closed = False

    def setProcessChannelMode(self, mode):
        pass

    def start(self, program, args):
        FakeProcess.started.append([program, *args])

    def waitForStarted(self, ms):
        return True

    def write(self, data):
        self.stdin += bytes(data)

    def closeWriteChannel(self):
        self.closed = True


CFG = {"disk": "/dev/vda", "mode": "erase", "username": "kiri", "hostname": "kea", "password": "Very$ecret;`x`",
       "fullname": "", "locale": "en_US.UTF-8", "keymap": "us", "timezone": "UTC", "desktop": "plasma",
       "shell": "", "kernel": "fiord", "autologin": False, "lowend": True, "greeter": "", "disk_size": 0}


@pytest.fixture(scope="session")
def app():
    from PySide6.QtCore import QCoreApplication
    return QCoreApplication.instance() or QCoreApplication([])


@pytest.fixture
def be(monkeypatch, app):
    monkeypatch.setattr(backend, "read_disks", lambda: [])
    monkeypatch.setattr(backend, "QProcess", FakeProcess)
    FakeProcess.started = []
    return backend.Backend(dry_run=True)


def test_install_sends_config_on_stdin_only(be):
    be.install(dict(CFG))
    assert len(FakeProcess.started) == 1
    argv = FakeProcess.started[0]
    assert argv[-1] == "-" and "--dry-run" in argv
    assert not any("ecret" in a for a in argv)
    sent = json.loads(be._proc.stdin)
    assert sent["password"] == CFG["password"]
    assert sent["kernel"] == "cachyos"
    assert be._proc.closed


def test_install_refuses_bad_config(be):
    be.install(dict(CFG, username="kiri;reboot"))
    be.install(dict(CFG, disk="/dev/sdz"))
    assert FakeProcess.started == []


def test_real_engine_runs_through_sudo_without_shell():
    program, args = backend.engine_command("/usr/lib/rawaru/engine.py", False)
    assert program == "sudo" and args == ["-n", "python3", "/usr/lib/rawaru/engine.py", "-"]


def test_progress_lines(be):
    be._line(json.dumps({"progress": 0.5, "status": "Installing mesa", "log": "hello"}))
    be._line("plain text")
    be._line("[1, 2]")
    assert be.progress == 0.5 and be.status == "Installing mesa"
    assert be._log == ["hello", "plain text", "[1, 2]"]


def test_log_is_private(be, tmp_path, monkeypatch):
    path = tmp_path / "rawaru.log"
    monkeypatch.setattr(backend, "private_log_path", lambda: str(path))
    be._log = ["a", "b"]
    be.saveLog()
    assert path.read_text() == "a\nb\n"
    if os.name == "posix":
        assert stat.S_IMODE(path.stat().st_mode) == 0o600
        os.chmod(path, 0o644)
        be.saveLog()
        assert stat.S_IMODE(path.stat().st_mode) == 0o600


def test_log_refuses_symlink(be, tmp_path, monkeypatch):
    if os.name != "posix":
        pytest.skip("posix only")
    target = tmp_path / "target"
    target.write_text("keep")
    link = tmp_path / "rawaru.log"
    link.symlink_to(target)
    monkeypatch.setattr(backend, "private_log_path", lambda: str(link))
    with pytest.raises(OSError):
        be.saveLog()
    assert target.read_text() == "keep"


def test_low_end_detection():
    assert backend.detect_low_end({"RAWARU_LOW_END": "1"}, 64_000_000, "") is True
    assert backend.detect_low_end({"RAWARU_LOW_END": "0"}, 1_000_000, "llvmpipe") is False
    assert backend.detect_low_end({}, 2_000_000, "AMD Radeon") is True
    assert backend.detect_low_end({}, 16_000_000, "llvmpipe (LLVM 19.1.0, 256 bits)") is True
    assert backend.detect_low_end({}, 16_000_000, "AMD Radeon RX 7800 XT") is False
    assert backend.detect_low_end({"QT_QUICK_BACKEND": "software"}, 16_000_000, "") is True


def test_package_available(monkeypatch):
    seen = []

    def run(cmd, **kw):
        seen.append(cmd)
        return subprocess.CompletedProcess(cmd, 0 if cmd[-1] == "linux-fiord" else 1, "", "")

    monkeypatch.setattr(backend.glob, "glob", lambda p: [])
    assert backend.package_available("linux-fiord", run) is True
    assert backend.package_available("crest-greeter", run) is False
    assert backend.package_available("x; reboot", run) is False
    assert all(c[:3] == ["pacman", "-Si", "--"] for c in seen)


def test_slots_use_shared_validators(be):
    assert be.usernameError("root")
    assert be.usernameError("") == ""
    assert be.hostnameError("bad host")
    assert be.passwordError("a\nb")
    assert be.fullnameError("a:b")

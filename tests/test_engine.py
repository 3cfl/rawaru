import io
import json
import subprocess

import pytest

import engine

CFG = {
    "disk": "/dev/vda", "mode": "erase", "username": "kiri", "hostname": "kea", "password": "s3cret pass:word",
    "fullname": "Kiri", "locale": "en_US.UTF-8", "keymap": "us", "timezone": "Pacific/Auckland",
    "desktop": "plasma", "shell": "", "kernel": "cachyos", "autologin": True, "lowend": False,
}


@pytest.fixture
def calls(monkeypatch):
    seen = []

    def fake_run(cmd, **kw):
        assert isinstance(cmd, list) and all(isinstance(a, str) for a in cmd)
        assert kw.get("shell") is not True
        seen.append((cmd, kw.get("input")))
        return subprocess.CompletedProcess(cmd, 0, "", "")

    monkeypatch.setattr(engine.subprocess, "run", fake_run)
    monkeypatch.setattr(engine, "DRY", False)
    return seen


def test_erase_commands_only_touch_the_target():
    for uefi in (True, False):
        cmds = engine.erase_cmds("/dev/nvme0n1", uefi)
        assert all(c[-1] == "/dev/nvme0n1" for c in cmds)
        assert cmds[0] == ["wipefs", "-af", "/dev/nvme0n1"]
    assert "-t1:ef00" in engine.erase_cmds("/dev/sda", True)[2]
    assert "-t1:ef02" in engine.erase_cmds("/dev/sda", False)[2]


def test_useradd_is_argv_and_validated():
    cmd = engine.useradd_cmd("kiri", "Kiri Te Wai")
    assert cmd[-2:] == ["--", "kiri"]
    assert "Kiri Te Wai" in cmd
    with pytest.raises(ValueError):
        engine.useradd_cmd("kiri; reboot", "")
    with pytest.raises(ValueError):
        engine.useradd_cmd("kiri", "a:b")


def test_chpasswd_input_rejects_line_injection():
    assert engine.chpasswd_input("kiri", "a:b c") == "kiri:a:b c\n"
    with pytest.raises(ValueError):
        engine.chpasswd_input("kiri", "x\nroot:x")


def test_password_goes_to_stdin_and_never_to_the_log(calls, capsys):
    engine.chroot("chpasswd", inp=engine.chpasswd_input("kiri", "topsecret"))
    cmd, inp = calls[-1]
    assert cmd == ["arch-chroot", engine.MNT, "chpasswd"]
    assert "topsecret" not in " ".join(cmd)
    assert inp == "kiri:topsecret\n"
    assert "topsecret" not in capsys.readouterr().out


def test_run_failure_raises_with_tail(monkeypatch):
    monkeypatch.setattr(engine, "DRY", False)
    monkeypatch.setattr(engine.subprocess, "run",
                        lambda cmd, **kw: subprocess.CompletedProcess(cmd, 3, "", "boom\n"))
    with pytest.raises(engine.CommandFailed) as e:
        engine.run(["false"])
    assert e.value.tail == ["boom"]


def test_pacstrap_cmd_rejects_odd_names():
    cmd = engine.pacstrap_cmd("/tmp/x.conf", ["base", "linux"])
    assert cmd[:4] == ["pacstrap", "-K", "-C", "/tmp/x.conf"]
    assert cmd[-2:] == ["base", "linux"]
    for bad in ["--overwrite=*", "a b", "$(x)", "-x"]:
        with pytest.raises(ValueError):
            engine.pacstrap_cmd("/tmp/x.conf", ["base", bad])


def nvidia():
    return engine.gpu_setup([("0x10de", 0x2684)])["pkgs"]


def test_packages_default_cachyos():
    pkgs = engine.build_packages(dict(CFG, shell=None, greeter=""), "amd", True, nvidia(), [])
    assert "linux-cachyos" in pkgs and "linux-cachyos-nvidia-open" in pkgs
    assert "fiordland-gaming" in pkgs and "amd-ucode" in pkgs and "efibootmgr" in pkgs
    assert len(pkgs) == len(set(pkgs))


def test_packages_arch_kernel_drops_cachyos_modules():
    pkgs = engine.build_packages(dict(CFG, kernel="arch", shell=None, greeter=""), "", False, nvidia(), [])
    assert not any(p.startswith("linux-cachyos") for p in pkgs)
    assert "nvidia-open" in pkgs


def test_packages_fiord_kernel():
    pkgs = engine.build_packages(dict(CFG, kernel="fiord", shell=None, greeter=""), "", True, nvidia(), [])
    assert "linux-fiord" in pkgs and "linux-fiord-headers" in pkgs and "nvidia-open-dkms" in pkgs
    assert "nvidia-open" not in pkgs and "linux" in pkgs
    back = engine.fallback_packages(pkgs)
    assert not any(p.startswith(("linux-fiord", "linux-cachyos")) for p in back)
    assert "nvidia-open" in back and "nvidia-open-dkms" not in back and "fiordland-gaming" not in back


def test_packages_low_end():
    pkgs = engine.build_packages(dict(CFG, lowend=True, shell=None, greeter=""), "", True, nvidia(), [])
    assert "fiordland-gaming" not in pkgs
    assert not any(p.startswith("lib32-") for p in pkgs)


def test_packages_crest_greeter():
    cfg = dict(CFG, desktop="hyprland", shell="crest", greeter="crest")
    assert "crest-greeter" in engine.build_packages(cfg, "", True, [], [])
    assert "crest-greeter" not in engine.fallback_packages(engine.build_packages(cfg, "", True, [], []))


def test_greetd_config():
    plain = engine.greetd_config("start-hyprland", "kiri", False)
    assert "tuigreet" in plain and "initial_session" not in plain
    crest = engine.greetd_config("start-hyprland", "kiri", True, "crest")
    assert 'command = "crest-greeter"' in crest and "tuigreet" not in crest
    assert 'user = "kiri"' in crest


def test_read_config_from_stdin_validates():
    cfg = engine.read_config("-", io.StringIO(json.dumps(CFG)))
    assert cfg["username"] == "kiri"
    with pytest.raises(ValueError):
        engine.read_config("-", io.StringIO(json.dumps(dict(CFG, disk="/dev/sda1"))))
    with pytest.raises(ValueError):
        engine.read_config("-", io.StringIO("not json"))


def test_probe_refuses_bad_disk(monkeypatch, capsys):
    monkeypatch.setattr(engine, "DRY", False)
    monkeypatch.setattr(engine.sys, "argv", ["engine.py", "--probe", "/dev/sda;reboot"])
    with pytest.raises(SystemExit):
        engine.main()


def test_main_rejects_bad_config(monkeypatch, capsys):
    monkeypatch.setattr(engine, "DRY", False)
    monkeypatch.setattr(engine.sys, "argv", ["engine.py", "--dry-run", "-"])
    monkeypatch.setattr(engine.sys, "stdin", io.StringIO(json.dumps(dict(CFG, username="root"))))
    with pytest.raises(SystemExit):
        engine.main()
    out = [json.loads(line) for line in capsys.readouterr().out.splitlines()]
    assert out[-1]["error"]


def test_dry_install_never_prints_the_password(monkeypatch, capsys):
    monkeypatch.setattr(engine.time, "sleep", lambda s: None)
    monkeypatch.setattr(engine, "DRY", False)
    monkeypatch.setattr(engine.sys, "argv", ["engine.py", "--dry-run", "-"])
    monkeypatch.setattr(engine.sys, "stdin", io.StringIO(json.dumps(dict(CFG, password="Zebra-Unique-77"))))
    monkeypatch.setattr(engine, "SERVICES", list(engine.SERVICES))
    engine.main()
    out = capsys.readouterr().out
    assert "Zebra-Unique-77" not in out
    assert json.loads(out.splitlines()[-1])["done"] is True
    assert "useradd" in out

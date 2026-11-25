import stat
import subprocess

import pytest

import checks

GOOD = {
    "disk": "/dev/sda", "mode": "erase", "username": "kiri", "hostname": "fiordland", "password": "hunter2 :x",
    "fullname": "Kiri Te Wai", "locale": "en_NZ.UTF-8", "keymap": "us", "timezone": "Pacific/Auckland",
    "desktop": "plasma", "shell": "", "kernel": "cachyos", "autologin": False, "lowend": False,
}

INJECT = ["a;reboot", "$(reboot)", "`id`", "a b", "a\nb", "../etc", "-rf", "a|b", "a&b", "a>b", "'", '"', "a\0b"]


@pytest.mark.parametrize("name", ["kiri", "_svc", "a-b_c9", "x" * 32])
def test_username_ok(name):
    assert checks.username_error(name) == ""


@pytest.mark.parametrize("name", INJECT + ["", "Kiri", "9lives", "x" * 33, "root", "greeter", "sddm", "été"])
def test_username_rejected(name):
    assert checks.username_error(name)


@pytest.mark.parametrize("name", ["fiordland", "a", "my-pc-2", "A" * 63])
def test_hostname_ok(name):
    assert checks.hostname_error(name) == ""


@pytest.mark.parametrize("name", INJECT + ["", "-pc", "pc-", "a" * 64, "pc.local", "pc_1"])
def test_hostname_rejected(name):
    assert checks.hostname_error(name)


def test_password_rules():
    assert checks.password_error("correct horse: battery $(x) `y`") == ""
    assert checks.password_error("")
    assert checks.password_error("a\nroot:pwned")
    assert checks.password_error("a\rb")
    assert checks.password_error("a\0b")
    assert checks.password_error("x" * 513)


@pytest.mark.parametrize("name", ["", "Kiri Te Wai", "Zoë O Brien"])
def test_fullname_ok(name):
    assert checks.fullname_error(name) == ""


@pytest.mark.parametrize("name", ["a:b", "a,b", "a\nb", "a\\b", "x" * 129])
def test_fullname_rejected(name):
    assert checks.fullname_error(name)


@pytest.mark.parametrize("disk", ["/dev/sda", "/dev/sdab", "/dev/vda", "/dev/nvme0n1", "/dev/mmcblk0", "/dev/xvdb"])
def test_disk_ok(disk):
    assert checks.disk_error(disk) == ""


@pytest.mark.parametrize("disk", ["", "/dev/sda1", "/dev/nvme0n1p1", "/dev/loop0", "/dev/sr0", "/dev/zram0",
                                  "/dev/sda;reboot", "/dev/../dev/sda", "sda", "/dev/sda ", "/tmp/x", None, 3])
def test_disk_rejected(disk):
    assert checks.disk_error(disk)


def test_partitions_belong_to_disk():
    assert checks.partition_error("/dev/sda", "/dev/sda2") == ""
    assert checks.partition_error("/dev/nvme0n1", "/dev/nvme0n1p3") == ""
    assert checks.partition_error("/dev/mmcblk0", "/dev/mmcblk0p1") == ""
    assert checks.partition_error("/dev/sda", "/dev/sdb2")
    assert checks.partition_error("/dev/sda", "/dev/sda")
    assert checks.partition_error("/dev/sda", "/dev/sda0")
    assert checks.partition_error("/dev/nvme0n1", "/dev/nvme0n12")
    assert checks.partition_error("/dev/sda", "/dev/sda2;reboot")
    assert checks.partition_name("/dev/nvme0n1", 2) == "/dev/nvme0n1p2"
    assert checks.partition_name("/dev/vda", 2) == "/dev/vda2"


def test_small_fields():
    assert checks.keymap_error("us") == ""
    assert checks.keymap_error("us\"; x") != ""
    assert checks.locale_error("en_US.UTF-8") == ""
    assert checks.locale_error("C.UTF-8") == ""
    assert checks.locale_error("en_US.UTF-8\nx") != ""
    assert checks.timezone_error("America/Argentina/Buenos_Aires") == ""
    assert checks.timezone_error("UTC") == ""
    assert checks.timezone_error("../../etc/shadow") != ""
    assert checks.timezone_error("Europe/../../etc") != ""
    assert checks.server_error("https://archive.archlinux.org/repos/2026/01/01/$repo/os/$arch") == ""
    assert checks.server_error("http://example.com/x") != ""
    assert checks.server_error("https://a.b/x\nServer = https://evil") != ""


def test_validate_config_good():
    out = checks.validate_config(dict(GOOD))
    assert out["disk"] == "/dev/sda"
    assert out["shell"] is None
    assert out["greeter"] == ""
    assert out["password"] == GOOD["password"]


@pytest.mark.parametrize("key,value", [
    ("disk", "/dev/sda; rm -rf /"), ("username", "root"), ("hostname", "a b"), ("password", "x\ny"),
    ("fullname", "a:b"), ("locale", "x"), ("keymap", "us us"), ("timezone", "../x"), ("desktop", "evil"),
    ("kernel", "linux-evil"), ("mode", "format-all"), ("autologin", "yes"), ("channel", "beta"),
    ("stable_server", "file:///etc"), ("greeter", "sddm"), ("disk_size", -1), ("username", 5),
])
def test_validate_config_rejects(key, value):
    cfg = dict(GOOD, **{key: value})
    with pytest.raises(checks.ConfigError):
        checks.validate_config(cfg)


def test_validate_config_manual_partitions():
    cfg = dict(GOOD, mode="manual", root="/dev/sda3", esp="/dev/sda1")
    out = checks.validate_config(cfg)
    assert (out["root"], out["esp"]) == ("/dev/sda3", "/dev/sda1")
    with pytest.raises(checks.ConfigError):
        checks.validate_config(dict(cfg, root="/dev/sdb3"))
    with pytest.raises(checks.ConfigError):
        checks.validate_config(dict(cfg, esp="/dev/sda3"))


def test_validate_config_alongside():
    out = checks.validate_config(dict(GOOD, mode="alongside", shrink="/dev/sda3", size=40e9))
    assert out["size"] == 40_000_000_000
    with pytest.raises(checks.ConfigError):
        checks.validate_config(dict(GOOD, mode="alongside", shrink="/dev/sdc3"))


def test_shell_must_match_desktop():
    out = checks.validate_config(dict(GOOD, desktop="hyprland", shell="crest", greeter="crest"))
    assert out["shell"] == "crest" and out["greeter"] == "crest"
    out = checks.validate_config(dict(GOOD, desktop="hyprland", shell="noctalia", greeter="crest"))
    assert out["greeter"] == ""
    with pytest.raises(checks.ConfigError):
        checks.validate_config(dict(GOOD, desktop="sway", shell="crest"))


class Runner:
    def __init__(self, table):
        self.table = table
        self.calls = []

    def __call__(self, cmd, **kw):
        self.calls.append(cmd)
        assert isinstance(cmd, list)
        assert kw.get("shell") is not True
        for prefix, (rc, out) in self.table.items():
            if tuple(cmd[:len(prefix)]) == prefix:
                return subprocess.CompletedProcess(cmd, rc, out, "")
        return subprocess.CompletedProcess(cmd, 1, "", "")


class BlockStat:
    st_mode = stat.S_IFBLK | 0o660


@pytest.fixture
def blockdev(monkeypatch):
    monkeypatch.setattr(checks.os, "stat", lambda p: BlockStat())
    monkeypatch.setattr(checks.os.path, "realpath", lambda p: p)


def test_check_target_ok(blockdev):
    run = Runner({("lsblk", "-dnbpo"): (0, "disk 0 64000000000\n"), ("findmnt",): (0, "/dev/sdb1\n"),
                  ("lsblk", "-no", "PKNAME"): (0, "sdb\n"), ("lsblk", "-lnpo"): (0, "\n\n")})
    assert checks.check_target("/dev/sda", 64000000000, run=run)


def test_check_target_refuses_boot_medium(blockdev):
    run = Runner({("lsblk", "-dnbpo"): (0, "disk 0 64000000000\n"), ("findmnt",): (0, "/dev/sda1\n"),
                  ("lsblk", "-no", "PKNAME"): (0, "sda\n"), ("lsblk", "-lnpo"): (0, "")})
    with pytest.raises(checks.ConfigError):
        checks.check_target("/dev/sda", run=run)


def test_check_target_refuses_changed_or_odd_disks(blockdev):
    base = {("findmnt",): (0, ""), ("lsblk", "-lnpo"): (0, "")}
    with pytest.raises(checks.ConfigError):
        checks.check_target("/dev/sda", 1, run=Runner({("lsblk", "-dnbpo"): (0, "disk 0 2\n"), **base}))
    with pytest.raises(checks.ConfigError):
        checks.check_target("/dev/sda", run=Runner({("lsblk", "-dnbpo"): (0, "part 0 2\n"), **base}))
    with pytest.raises(checks.ConfigError):
        checks.check_target("/dev/sda", run=Runner({("lsblk", "-dnbpo"): (0, "disk 1 2\n"), **base}))
    with pytest.raises(checks.ConfigError):
        checks.check_target("/dev/sda", run=Runner({("lsblk", "-dnbpo"): (0, "disk 0 2\n"),
                                                    ("findmnt",): (0, ""), ("lsblk", "-lnpo"): (0, "/\n")}))
    with pytest.raises(checks.ConfigError):
        checks.check_target("/dev/sda;x", run=Runner(base))


def test_check_target_refuses_symlink(monkeypatch):
    monkeypatch.setattr(checks.os.path, "realpath", lambda p: "/dev/sdb")
    with pytest.raises(checks.ConfigError):
        checks.check_target("/dev/sda", run=Runner({}))


def test_check_partition():
    assert checks.check_partition("/dev/sda", "/dev/sda2", run=Runner({("lsblk",): (0, "sda\n")}))
    with pytest.raises(checks.ConfigError):
        checks.check_partition("/dev/sda", "/dev/sda2", run=Runner({("lsblk",): (0, "sdb\n")}))

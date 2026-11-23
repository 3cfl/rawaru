import json
import os
import re
import subprocess

MIB = 1024 * 1024
GIB = 1024 * MIB
MIN_FIORD = 20 * 1000**3
WIN_MARGIN = 10 * GIB
ESP_TYPE = "C12A7328-F81F-11D2-BA4B-00A0C93EC93B"
BASIC_DATA = "EBD0A0A2-B9E5-4433-87C0-68B6B72699C7"
MSR_TYPE = "E3C9E316-0B5C-4DB8-817D-F92DF00215AE"
WINRE_TYPE = "DE94BBA4-06D1-4D40-A16A-BFD50179D6AC"
BIOS_BOOT = "21686148-6449-6E6F-744E-656564454649"
MBR_ESP = "EF"
MIN_MANUAL = 16 * 1000**3


def sh(cmd, inp=None, timeout=60):
    p = subprocess.run(cmd, input=inp, capture_output=True, text=True, timeout=timeout)
    return p.returncode, p.stdout, p.stderr


def table(disk):
    rc, out, _ = sh(["sfdisk", "-J", disk])
    if rc != 0 or not out.strip():
        return None
    return json.loads(out)["partitiontable"]


def blkid(part):
    rc, out, _ = sh(["blkid", "-p", "-o", "export", part])
    info = {}
    for line in out.splitlines():
        k, _, v = line.partition("=")
        info[k] = v
    return info


def free_blocks(pt):
    sector = pt.get("sectorsize", 512)
    align = MIB // sector
    first = pt.get("firstlba", 2048)
    last = pt.get("lastlba", 0)
    parts = sorted(pt.get("partitions", []), key=lambda p: p["start"])
    blocks = []
    cur = first
    for p in parts + [{"start": last + 1, "size": 0}]:
        start = -(-cur // align) * align
        end = p["start"] - 1
        if end - start + 1 >= align:
            blocks.append((start, end - start + 1))
        cur = max(cur, p["start"] + p["size"])
    return [(s * sector, n * sector) for s, n in blocks]


def ntfs_min(part):
    rc, out, err = sh(["ntfsresize", "--info", "--no-progress-bar", part], timeout=300)
    text = out + err
    m = re.search(r"You might resize at (\d+) bytes", text)
    if m:
        return int(m.group(1)), ""
    if re.search(r"hibernat|Windows is hibernated", text, re.I):
        return 0, "Windows is hibernated or Fast Startup is on. In Windows, turn off Fast Startup, then shut down fully."
    if re.search(r"unclean|dirty|chkdsk|inconsistent", text, re.I):
        return 0, "This Windows partition needs a disk check. Boot Windows, run chkdsk /f, then shut down fully."
    if re.search(r"bitlocker", text, re.I):
        return 0, "This partition is encrypted with BitLocker. Turn off BitLocker or Device Encryption in Windows first."
    return 0, (text.strip().splitlines() or ["ntfsresize could not read this partition."])[-1]


def os_names():
    names = {}
    try:
        rc, out, _ = sh(["os-prober"], timeout=60)
    except (OSError, subprocess.TimeoutExpired):
        return names
    for line in out.splitlines():
        bits = line.split(":")
        if len(bits) >= 3:
            names[bits[0].split("@")[0]] = bits[1] or bits[2]
    return names


def partitions(pt):
    sector = pt.get("sectorsize", 512)
    out = []
    for p in pt.get("partitions", []):
        ptype = p.get("type", "").upper()
        info = blkid(p["node"])
        out.append({"node": p["node"], "size": p["size"] * sector, "fs": info.get("TYPE", ""),
                    "label": info.get("LABEL") or info.get("PARTLABEL") or p.get("name", ""),
                    "esp": ptype in (ESP_TYPE, MBR_ESP), "biosBoot": ptype == BIOS_BOOT,
                    "usable": p["size"] * sector >= MIN_MANUAL and ptype not in (ESP_TYPE, MBR_ESP, BIOS_BOOT, MSR_TYPE)})
    return out


def probe(disk, uefi=None):
    if uefi is None:
        uefi = os.path.isdir("/sys/firmware/efi")
    res = {"disk": disk, "uefi": uefi, "gpt": False, "esp": "", "system": "", "options": [], "notes": [],
           "parts": [], "biosBoot": False}
    pt = table(disk)
    if not pt:
        return res
    res["gpt"] = pt.get("label") == "gpt"
    res["parts"] = partitions(pt)
    res["biosBoot"] = any(p["biosBoot"] for p in res["parts"])
    if not uefi:
        res["notes"].append("Installing next to another system needs a computer started in UEFI mode.")
        return res
    if not res["gpt"]:
        res["notes"].append("This disk uses the old MBR layout, so only a full erase is possible.")
        return res
    parts = pt.get("partitions", [])
    sector = pt.get("sectorsize", 512)
    esps = [p for p in parts if p.get("type", "").upper() == ESP_TYPE]
    if not esps:
        res["notes"].append("No EFI system partition on this disk, so only a full erase is possible.")
        return res
    res["esp"] = esps[0]["node"]
    names = os_names()
    for v in names.values():
        if "windows" in v.lower():
            res["system"] = "Windows"
            break
    if not res["system"] and names:
        res["system"] = next(iter(names.values()))
    blocks = free_blocks(pt)
    biggest = max((n for _, n in blocks), default=0)
    if biggest >= MIN_FIORD:
        res["options"].append({"kind": "free", "part": "", "label": "Free space", "max": biggest, "min": MIN_FIORD,
                               "partSize": 0})
    for p in parts:
        ptype = p.get("type", "").upper()
        if ptype in (ESP_TYPE, MSR_TYPE, WINRE_TYPE):
            continue
        size = p["size"] * sector
        info = blkid(p["node"])
        fs = info.get("TYPE", "")
        if fs == "BitLocker":
            res["notes"].append(f"{p['node']} is encrypted with BitLocker. Turn off BitLocker or Device Encryption "
                                "in Windows to shrink it.")
            continue
        if fs != "ntfs" or ptype != BASIC_DATA or size < MIN_FIORD + WIN_MARGIN:
            continue
        low, why = ntfs_min(p["node"])
        if not low:
            res["notes"].append(f"{p['node']}: {why}")
            continue
        keep = low + WIN_MARGIN
        room = size - keep
        if room < MIN_FIORD:
            res["notes"].append(f"{p['node']} is too full to make room for Fiordland.")
            continue
        label = info.get("LABEL") or "Windows"
        res["options"].append({"kind": "shrink", "part": p["node"], "label": label, "max": room, "min": MIN_FIORD,
                               "partSize": size})
    res["options"].sort(key=lambda o: (o["kind"] != "shrink", -o["max"]))
    return res


def snapshot(disk):
    pt = table(disk) or {}
    return {p["node"]: p for p in pt.get("partitions", [])}

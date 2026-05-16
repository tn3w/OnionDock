#!/usr/bin/env python3
import json
import os
import pwd
import re
import secrets
import signal
import subprocess
import sys
import time
from typing import NoReturn

DATA = "/var/lib/tor"
HS = f"{DATA}/hidden_service"
LOG = f"{DATA}/notices.log"
RUN_DIR = "/run/tor"
TORRC_TMPL = "/etc/tor/torrc.tmpl"
TORRC = f"{DATA}/torrc"
PT_DIR = "/usr/local/bin/pluggable_transports"
PT_CONFIG = "/etc/tor/pt_config.json"
VG_CONFIG = "/etc/tor/vanguards.conf"
KEY_SECRET = "/run/secrets/hs_ed25519_secret_key"

TRANSPORT = os.environ.get("TOR_TRANSPORT_TYPE", "snowflake")
PORTS = os.environ.get("TOR_SERVICE_PORTS", "80:webapp:80")
LEVEL = os.environ.get("SECURITY_LEVEL", "high")

PLUGINS = {"obfs4": "lyrebird", "snowflake": "snowflake", "conjure": "conjure"}
PORT_RE = re.compile(r"^(\d{1,5}):([A-Za-z0-9._-]+):(\d{1,5})$")

VG_PROFILES = {
    "high": [
        ("guards", ["--disable_bandguards", "--disable_rendguard"]),
        ("band",   ["--disable_vanguards",  "--disable_rendguard"]),
        ("rend",   ["--disable_vanguards",  "--disable_bandguards"]),
    ],
    "medium": [
        ("guards", ["--disable_bandguards", "--disable_rendguard", "--disable_cbtverify"]),
        ("band",   ["--disable_vanguards",  "--disable_rendguard", "--disable_cbtverify"]),
    ],
    "low": [
        ("guards", ["--disable_bandguards", "--disable_rendguard", "--disable_cbtverify"]),
    ],
}

rng = secrets.SystemRandom()
children: list[subprocess.Popen] = []


def die(msg: str) -> NoReturn:
    print(f"[!] {msg}", file=sys.stderr)
    sys.exit(1)


def secure_dir(path: str, uid: int, gid: int) -> None:
    if os.path.islink(path):
        die(f"refusing to operate on symlink: {path}")
    os.makedirs(path, mode=0o700, exist_ok=True)
    if os.path.islink(path):
        die(f"path became symlink: {path}")
    os.chown(path, uid, gid, follow_symlinks=False)
    os.chmod(path, 0o700)


def install_secret_key(uid: int, gid: int) -> None:
    if not os.path.exists(KEY_SECRET):
        return
    dst = f"{HS}/hs_ed25519_secret_key"
    with open(KEY_SECRET, "rb") as src:
        data = src.read()
    fd = os.open(dst, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "wb") as out:
        out.write(data)
    os.chown(dst, uid, gid, follow_symlinks=False)
    print("[+] installed onion key from /run/secrets")


def drop_privileges() -> None:
    if os.geteuid() != 0:
        return
    tor = pwd.getpwnam("tor")
    secure_dir(DATA, tor.pw_uid, tor.pw_gid)
    secure_dir(HS, tor.pw_uid, tor.pw_gid)
    secure_dir(RUN_DIR, tor.pw_uid, tor.pw_gid)
    install_secret_key(tor.pw_uid, tor.pw_gid)

    os.setgroups([])
    os.setgid(tor.pw_gid)
    os.setuid(tor.pw_uid)
    if os.getuid() != tor.pw_uid or os.geteuid() != tor.pw_uid:
        die("setuid failed")
    if os.getgid() != tor.pw_gid or os.getegid() != tor.pw_gid:
        die("setgid failed")
    os.environ.clear()
    os.environ.update({
        "HOME": tor.pw_dir,
        "PATH": "/venv/bin:/usr/local/bin/pluggable_transports:/usr/local/bin:/usr/bin:/bin",
        "USER": "tor",
    })


def parse_ports() -> list[str]:
    out = []
    for raw in PORTS.split(","):
        m = PORT_RE.match(raw.strip())
        if m is None:
            die(f"invalid port mapping: {raw}")
        outer, host, inner = int(m[1]), m[2], int(m[3])
        if not (1 <= outer <= 65535 and 1 <= inner <= 65535):
            die(f"port out of range: {raw}")
        out.append(f"HiddenServicePort {outer} {host}:{inner}")
    return out


def parse_transport() -> list[str]:
    if TRANSPORT == "none" or not os.path.exists(PT_CONFIG):
        return []
    plugin = PLUGINS.get(TRANSPORT)
    if not plugin:
        print(f"[!] unknown transport: {TRANSPORT}", file=sys.stderr)
        return []

    with open(PT_CONFIG) as f:
        data = json.load(f)

    line = data.get("pluggableTransports", {}).get(plugin, "")
    if not line:
        return []
    line = line.replace("${pt_path}", f"{PT_DIR}/")

    bridges = data.get("bridges", {}).get(TRANSPORT, [])
    sample = rng.sample(bridges, min(2, len(bridges)))
    sample = [re.sub(r"iat-mode=[01]", "iat-mode=2", f"Bridge {b}") for b in sample]

    return ["", "UseBridges 1", line, *sample]


def write_torrc() -> None:
    with open(TORRC_TMPL) as f:
        base = f.read().rstrip()
    body = "\n".join([base, "", *parse_ports(), *parse_transport(), ""])
    fd = os.open(TORRC, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(body)


def bootstrapped() -> bool:
    try:
        with open(LOG) as f:
            return "Bootstrapped 100" in f.read()
    except FileNotFoundError:
        return False


def wait_bootstrap(proc: subprocess.Popen) -> None:
    while proc.poll() is None:
        if bootstrapped():
            return
        time.sleep(1)
    die("tor died during bootstrap")


def print_onion() -> None:
    try:
        with open(f"{HS}/hostname") as f:
            print(f"[+] Onion: {f.read().strip()}")
    except FileNotFoundError:
        print("[!] hostname file missing", file=sys.stderr)


def spawn_vanguards() -> None:
    cfg = ["--config", VG_CONFIG] if os.path.exists(VG_CONFIG) else []
    for name, flags in VG_PROFILES.get(LEVEL, VG_PROFILES["low"]):
        children.append(subprocess.Popen([
            "vanguards",
            "--state", f"{DATA}/vanguards_{name}.state",
            "--control_port", "9051",
            *cfg, *flags,
        ], stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT))


def shutdown(*_) -> NoReturn:
    for p in children:
        if p.poll() is None:
            p.terminate()
    for p in children:
        try:
            p.wait(timeout=5)
        except subprocess.TimeoutExpired:
            p.kill()
    sys.exit(0)


def supervise() -> None:
    while True:
        for p in children:
            rc = p.poll()
            if rc is not None:
                print(f"[!] child exited (pid={p.pid} rc={rc}) shutting down", file=sys.stderr)
                shutdown()
        time.sleep(2)


def main() -> None:
    drop_privileges()
    print(f"[+] OnionDock | level={LEVEL} transport={TRANSPORT} ports={PORTS}", flush=True)

    open(LOG, "w").close()
    write_torrc()

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)

    tor = subprocess.Popen(["tor", "-f", TORRC])
    children.append(tor)

    wait_bootstrap(tor)
    print_onion()
    spawn_vanguards()

    supervise()


if __name__ == "__main__":
    main()

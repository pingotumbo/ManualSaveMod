#!/usr/bin/env python3
# =============================================================================
# ManualSave_Watcher.py  (Linux / Steam Deck / macOS)
# Python port of Windows/ManualSave_Watcher.ps1
# =============================================================================
# Phase 2b: foundation. The lock, heartbeat, signal poll, dispatcher and exit
# cleanup are real. The 11 game operations (SAVE, LOAD, etc.) are stubbed and
# reply STATUS=NOT_IMPLEMENTED until Phase 2d ports them one by one.
# =============================================================================

import os
import re
import sys
import time
import shutil
import signal
import subprocess
from datetime import datetime
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths relative to this script (Linux/ or MacOS/ sibling of the mod root).
# ---------------------------------------------------------------------------
SCRIPT_DIR         = Path(__file__).resolve().parent
MOD_ROOT           = SCRIPT_DIR.parent
USERDIR_TXT        = SCRIPT_DIR / "ManualSave_UserDir.txt"
LEGACY_USERDIR_TXT = MOD_ROOT  / "ManualSave_UserDir.txt"   # pre-v1.5.4 fallback
PLACEHOLDER_DIR    = MOD_ROOT  / "placeholders"

# ---------------------------------------------------------------------------
# Logging helper (writes both to stdout and to a small log on disk later).
# ---------------------------------------------------------------------------
def log(msg: str) -> None:
    print(f"[ManualSave_Watcher] {msg}", flush=True)

# ---------------------------------------------------------------------------
# Migration safety net (v1.5.4 layout change).
# Pre-v1.5.4 the watcher and ManualSave_UserDir.txt lived in the mod root.
# From v1.5.4 they live inside Linux/ or MacOS/. If an old root-level file
# survives, copy its contents over the freshly shipped default so a user with
# a customised Zomboid path doesn't lose it on update.
# ---------------------------------------------------------------------------
if LEGACY_USERDIR_TXT.exists() and not USERDIR_TXT.exists():
    try:
        shutil.copyfile(LEGACY_USERDIR_TXT, USERDIR_TXT)
    except OSError:
        pass

def expand_env(s: str) -> str:
    """Expand $VAR / ${VAR} / ~ / %VAR% so users can write either Unix or
    Windows-style env references in ManualSave_UserDir.txt without surprises."""
    s = os.path.expandvars(s)
    s = re.sub(r"%([^%]+)%", lambda m: os.environ.get(m.group(1), m.group(0)), s)
    s = os.path.expanduser(s)
    return s

def read_userdir_config():
    """First non-comment, non-empty line of ManualSave_UserDir.txt, expanded."""
    if not USERDIR_TXT.exists():
        return ""
    try:
        for raw in USERDIR_TXT.read_text(encoding="utf-8", errors="replace").splitlines():
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            return expand_env(line)
    except OSError:
        pass
    return ""

def write_userdir_config(path: str) -> None:
    """Persist the chosen path back to ManualSave_UserDir.txt with a header."""
    USERDIR_TXT.write_text(
        "# Edit this path if your Zomboid folder is somewhere other than the default.\n"
        "# Default on Linux / Steam Deck / macOS: ~/Zomboid\n"
        f"{path}\n",
        encoding="utf-8",
    )

def prompt_zomboid_path(current: str) -> str:
    """Interactive fallback when the saved/default path doesn't exist. Mirrors
    Read-ZomboidPath in the .ps1. Catches Ctrl+C explicitly because while the
    program is blocked in input() Python raises KeyboardInterrupt before our
    SIGINT handler gets a chance to run."""
    try:
        while True:
            if current:
                log(f"Current path: {current}")
                typed = input("New path (Enter to keep current): ").strip()
                if not typed:
                    return current
            else:
                log(f"Zomboid folder not found at: {Path.home() / 'Zomboid'}")
                typed = input("Enter Zomboid folder path: ").strip()
                if not typed:
                    continue
            expanded = expand_env(typed)
            if Path(expanded).is_dir():
                write_userdir_config(expanded)
                log("Path saved.")
                return expanded
            log(f"Path not found: {expanded}")
    except (KeyboardInterrupt, EOFError):
        print()
        log("Cancelled by user. Exiting.")
        sys.exit(0)

# ---------------------------------------------------------------------------
# Resolve ZomboidRoot using the same priority order as the .ps1:
#   1. `path` CLI arg  -> always re-prompt
#   2. saved config    -> use if exists
#   3. ~/Zomboid       -> use if exists
#   4. prompt          -> ask interactively
# ---------------------------------------------------------------------------
_saved        = read_userdir_config()
_userdir_src  = "config"
_default_home = Path.home() / "Zomboid"

if len(sys.argv) > 1 and sys.argv[1].lower() == "path":
    ZomboidRoot  = prompt_zomboid_path(_saved)
elif _saved and Path(_saved).is_dir():
    ZomboidRoot  = _saved
elif _default_home.is_dir():
    ZomboidRoot  = str(_default_home)
    _userdir_src = "default"
else:
    ZomboidRoot  = prompt_zomboid_path("")

ZomboidRoot = str(Path(ZomboidRoot))

# ---------------------------------------------------------------------------
# Derived constants (mirror the .ps1 names so the protocol is identical).
# ---------------------------------------------------------------------------
LuaDir         = Path(ZomboidRoot) / "Lua"
SIGNAL         = LuaDir / "ManualSave_Signal.txt"
INDEX          = LuaDir / "ManualSave_Index.txt"
DONE           = LuaDir / "ManualSave_Done.txt"
SAVES          = Path(ZomboidRoot) / "Saves"

# Honour the user-configurable backup folder set in Settings > Paths
# (Config key BACKUP_DIR, persisted by the Lua side in ManualSave_Config.txt).
BACKUPS        = Path(ZomboidRoot) / "ManualSaves"
_cfg_file      = LuaDir / "ManualSave_Config.txt"
if _cfg_file.exists():
    try:
        for line in _cfg_file.read_text(encoding="utf-8", errors="replace").splitlines():
            m = re.match(r"^\s*BACKUP_DIR\s*=\s*(.*)$", line)
            if m:
                val = expand_env(m.group(1).strip())
                if val and Path(val).is_dir():
                    BACKUPS = Path(val)
                    log(f"Backups: {BACKUPS}  (from Settings > Paths)")
                else:
                    log(f"Configured BACKUP_DIR not found, using default: {BACKUPS}")
                    if val:
                        log(f"  configured: {val}")
                break
    except OSError:
        pass

THUMBS         = SAVES / "ManualSave_Thumbs"
SCREEN_REQ     = LuaDir / "ManualSave_ScreenReq.txt"
SCREEN_DONE    = LuaDir / "ManualSave_ScreenDone.txt"
SCREEN_LOG     = LuaDir / "ManualSave_ScreenLog.txt"
THUMB_PENDING  = LuaDir / "ManualSave_ThumbPending.png"
LOCK_FILE      = LuaDir / "ManualSave_Watcher.lock"
HEARTBEAT      = LuaDir / "ManualSave_Heartbeat.txt"
VANILLA_OWNED  = LuaDir / "ManualSave_VanillaOwned.txt"

LuaDir.mkdir(parents=True, exist_ok=True)
BACKUPS.mkdir(parents=True, exist_ok=True)
THUMBS.mkdir(parents=True, exist_ok=True)
if not INDEX.exists():
    INDEX.write_text("", encoding="utf-8")

# ---------------------------------------------------------------------------
# Lock file. Same protocol as the .ps1: PID inside, stale lock detection by
# checking that the recorded PID is alive AND still belongs to a python
# interpreter (so a recycled PID grabbed by an unrelated process can't keep
# us out forever).
# ---------------------------------------------------------------------------
def _pid_alive(pid: int) -> bool:
    if not pid or pid <= 0:
        return False
    try:
        os.kill(pid, 0)
        return True
    except (OSError, ProcessLookupError):
        return False

def _pid_is_python(pid: int) -> bool:
    """Best-effort check that pid is still a python interpreter.
    Linux: /proc/<pid>/comm. macOS: `ps -p <pid> -o comm=`. Falls back to
    'assume yes' if neither works (better to err on the side of not stealing
    a real watcher's lock than to nuke it)."""
    try:
        with open(f"/proc/{pid}/comm", "r", encoding="utf-8", errors="replace") as f:
            return "python" in f.read().lower()
    except OSError:
        pass
    try:
        out = subprocess.check_output(
            ["ps", "-p", str(pid), "-o", "comm="],
            stderr=subprocess.DEVNULL, timeout=2,
        )
        return "python" in out.decode("utf-8", "replace").lower()
    except (subprocess.SubprocessError, OSError, FileNotFoundError):
        pass
    return True   # unknown -> safe default = don't steal the lock

def _watcher_alive(pid: int) -> bool:
    return _pid_alive(pid) and _pid_is_python(pid)

def _read_lock_pid():
    try:
        return int(LOCK_FILE.read_text(encoding="utf-8").strip())
    except (OSError, ValueError):
        return None

def _acquire_lock() -> bool:
    """Returns True if we got the lock. False if another watcher is alive."""
    # Clean stale lock first.
    if LOCK_FILE.exists():
        stale_pid = _read_lock_pid()
        if not _watcher_alive(stale_pid or 0):
            try: LOCK_FILE.unlink()
            except OSError: pass
    # Atomic create-exclusive.
    try:
        fd = os.open(str(LOCK_FILE), os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o644)
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(str(os.getpid()))
        return True
    except FileExistsError:
        existing = _read_lock_pid()
        if _watcher_alive(existing or 0):
            log(f"Already running (PID {existing}). Exiting.")
            return False
        log(f"Stale lock detected (PID {existing} not a python process). Clearing and retrying.")
        try: LOCK_FILE.unlink()
        except OSError: pass
        time.sleep(0.2)
        try:
            fd = os.open(str(LOCK_FILE), os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o644)
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                f.write(str(os.getpid()))
            return True
        except OSError:
            log("Could not acquire lock even after clearing. Exiting.")
            return False

def _release_lock() -> None:
    try:
        if LOCK_FILE.exists():
            pid_in_lock = _read_lock_pid()
            if pid_in_lock == os.getpid():
                LOCK_FILE.unlink()
    except OSError:
        pass

if not _acquire_lock():
    time.sleep(3)
    sys.exit(0)

# Cleanup hooks: release lock on Ctrl+C / SIGTERM / normal exit.
def _shutdown_handler(signum, frame):
    log(f"Received signal {signum}, shutting down.")
    _release_lock()
    sys.exit(0)

signal.signal(signal.SIGINT,  _shutdown_handler)
signal.signal(signal.SIGTERM, _shutdown_handler)
import atexit
atexit.register(_release_lock)

# ---------------------------------------------------------------------------
# Banner + status lines (mirror the .ps1's first prints so users see the same
# kind of output regardless of OS).
# ---------------------------------------------------------------------------
log("Starting...")
log(f"UserDir: {ZomboidRoot}  ({_userdir_src})")
log(f"Signal : {SIGNAL}")
log(f"Backups: {BACKUPS}")

# ---------------------------------------------------------------------------
# Signal protocol helpers.
# ---------------------------------------------------------------------------
def read_signal(path: Path) -> dict:
    params = {}
    try:
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            if "=" in line:
                k, v = line.split("=", 1)
                params[k.strip()] = v.rstrip("\r\n").strip()
    except OSError:
        pass
    return params

def write_done(status: str, action: str, extra: dict = None) -> None:
    lines = [f"STATUS={status}", f"ACTION={action}"]
    if extra:
        for k, v in extra.items():
            lines.append(f"{k}={v}")
    DONE.write_text("\n".join(lines) + "\n", encoding="utf-8")

# ---------------------------------------------------------------------------
# Heartbeat. Counter increments every poll tick; PZ reads this file every
# ~120 game ticks to know the watcher is alive. The .ps1 uses FileShare.Read
# to avoid sharing-violation errors on Windows; on Linux/macOS files are
# always shareable so a plain write is fine.
# ---------------------------------------------------------------------------
_hb_counter = 0
def _heartbeat_tick() -> None:
    global _hb_counter
    _hb_counter += 1
    try:
        HEARTBEAT.write_text(f"{_hb_counter}\n", encoding="ascii")
    except OSError:
        pass   # next tick will write again

# ---------------------------------------------------------------------------
# Index + VanillaOwned helpers. Same line format as the .ps1.
# ---------------------------------------------------------------------------
def update_index() -> None:
    entries = []
    if BACKUPS.is_dir():
        for g in sorted(p for p in BACKUPS.iterdir() if p.is_dir()):
            for w in sorted(p for p in g.iterdir() if p.is_dir()):
                for s in sorted(p for p in w.iterdir() if p.is_dir()):
                    entries.append(f"{g.name}|{w.name}|{s.name}")
    INDEX.write_text("\n".join(entries) + ("\n" if entries else ""), encoding="utf-8")

def add_to_index(gmode: str, world: str, slot: str) -> None:
    entry = f"{gmode}|{world}|{slot}"
    existing = []
    if INDEX.exists():
        existing = INDEX.read_text(encoding="utf-8", errors="replace").splitlines()
    if entry not in existing:
        with INDEX.open("a", encoding="utf-8") as f:
            f.write(entry + "\n")

def _read_vanilla_owned_lines():
    if not VANILLA_OWNED.exists():
        return []
    return [
        ln for ln in VANILLA_OWNED.read_text(encoding="utf-8", errors="replace").splitlines()
        if ln.strip()
    ]

def add_vanilla_owned(gmode: str, world: str, slot: str, session_id: str) -> None:
    entry = f"{gmode}|{world}|{slot}|{session_id}"
    if entry not in _read_vanilla_owned_lines():
        with VANILLA_OWNED.open("a", encoding="utf-8") as f:
            f.write(entry + "\n")

def remove_vanilla_owned(gmode: str, slot: str, session_id: str = None) -> None:
    lines = _read_vanilla_owned_lines()
    if not lines:
        return
    g_esc = re.escape(gmode)
    s_esc = re.escape(slot)
    if session_id:
        pat = re.compile(rf"^{g_esc}\|[^|]*\|{s_esc}\|{re.escape(session_id)}$")
    else:
        pat = re.compile(rf"^{g_esc}\|[^|]*\|{s_esc}\|")
    kept = [ln for ln in lines if not pat.match(ln)]
    VANILLA_OWNED.write_text("\n".join(kept) + ("\n" if kept else ""), encoding="utf-8")

def test_vanilla_owned(gmode: str, slot: str, session_id: str = None) -> bool:
    lines = _read_vanilla_owned_lines()
    if not lines:
        return False
    g_esc = re.escape(gmode)
    s_esc = re.escape(slot)
    if session_id:
        pat = re.compile(rf"^{g_esc}\|[^|]*\|{s_esc}\|{re.escape(session_id)}$")
    else:
        pat = re.compile(rf"^{g_esc}\|[^|]*\|{s_esc}\|")
    return any(pat.match(ln) for ln in lines)

def get_vanilla_owned_entries():
    result = []
    for ln in _read_vanilla_owned_lines():
        parts = ln.split("|", 3)
        if len(parts) == 4:
            result.append({"gmode": parts[0], "world": parts[1], "slot": parts[2], "sessionId": parts[3]})
    return result

# ---------------------------------------------------------------------------
# Folder size in MB (string, invariant culture). Used by SAVE/IMPORT meta.
# ---------------------------------------------------------------------------
def folder_size_mb(path: Path) -> str:
    total = 0
    if not path.is_dir():
        return "0"
    for root, _, files in os.walk(path):
        for fn in files:
            try:
                total += (Path(root) / fn).stat().st_size
            except OSError:
                pass
    if total <= 0:
        return "0"
    return f"{round(total / (1024 * 1024), 1):.1f}"   # always dot, no locale

# ---------------------------------------------------------------------------
# Tree-copy helpers. The .ps1 uses robocopy /E (merge, keep extras) and
# /MIR (mirror, drop extras). shutil maps to that cleanly.
# ---------------------------------------------------------------------------
def copy_tree_merge(src: Path, dst: Path) -> bool:
    """robocopy /E equivalent: copy src into dst, overwriting collisions,
    keeping any pre-existing file in dst that isn't in src."""
    try:
        shutil.copytree(src, dst, dirs_exist_ok=True)
        return True
    except OSError as e:
        log(f"copy_tree_merge failed {src} -> {dst}: {e}")
        return False

def copy_tree_mirror(src: Path, dst: Path) -> bool:
    """robocopy /MIR equivalent: make dst exactly match src, removing any
    file in dst that isn't in src."""
    if dst.exists():
        try: shutil.rmtree(dst)
        except OSError as e:
            log(f"copy_tree_mirror could not clear dst {dst}: {e}")
            return False
    try:
        shutil.copytree(src, dst)
        return True
    except OSError as e:
        log(f"copy_tree_mirror failed {src} -> {dst}: {e}")
        return False

def copy_thumb_for_clone(gmode: str, world: str, old_slot: str, new_slot: str) -> None:
    """Promote the OLD slot's thumb to the NEW slot. Tries the canonical
    THUMBS folder first, then falls back to the backup's embedded thumb.png."""
    old_thumb = THUMBS / f"{old_slot}.png"
    new_thumb = THUMBS / f"{new_slot}.png"
    if old_thumb.exists():
        try:
            shutil.copyfile(old_thumb, new_thumb)
            return
        except OSError: pass
    embedded = BACKUPS / gmode / world / old_slot / "thumb.png"
    if embedded.exists():
        THUMBS.mkdir(parents=True, exist_ok=True)
        try:
            shutil.copyfile(embedded, new_thumb)
        except OSError: pass

# ---------------------------------------------------------------------------
# Crash recovery (real port deferred to Phase 2d). For now we keep the
# placeholder so the watcher boot sequence matches the .ps1's shape: anything
# in VanillaOwned at startup means PZ exited uncleanly, but until SAVE/LOAD
# are ported there's nothing useful to recover — emit a notice and move on.
# ---------------------------------------------------------------------------
def invoke_crash_recovery() -> None:
    """Replays the .ps1 logic: any VanillaOwned entry at startup means PZ
    exited without going through SESSION_END, so we copy the vanilla save
    into a timestamped recovery slot, write its meta, and clear the entry."""
    reenter_flag = LuaDir / "ManualSave_ReenterFlag.txt"
    if reenter_flag.exists():
        log("Reenter flag found, skipping crash recovery.")
        return
    entries = get_vanilla_owned_entries()
    if not entries:
        return
    crash_log = LuaDir / "ManualSave_CrashRecovery.txt"
    recovered = []
    for e in entries:
        gmode, world, slot, sid = e["gmode"], e["world"], e["slot"], e["sessionId"]
        vanilla_path = SAVES / gmode / slot
        if not vanilla_path.is_dir():
            remove_vanilla_owned(gmode, slot, sid)
            continue
        ts            = datetime.now().strftime("%Y%m%d_%H%M")
        recovery_slot = f"{slot}_crash_{ts}"
        dst           = BACKUPS / gmode / world / recovery_slot
        dst.mkdir(parents=True, exist_ok=True)
        if copy_tree_merge(vanilla_path, dst):
            size  = folder_size_mb(dst)
            meta  = LuaDir / f"ManualSaves_Meta_{_safe_name(gmode)}_{_safe_name(world)}_{_safe_name(recovery_slot)}.txt"
            meta.write_text("\n".join([
                f"DATE={datetime.now().strftime('%d %b %Y %H:%M')}",
                "TYPE=CRASH_RECOVERY",
                f"GMODE={gmode}",
                f"WORLD={world}",
                f"SLOT={recovery_slot}",
                f"SIZE={size} MB",
                f"SOURCE_SLOT={slot}",
            ]) + "\n", encoding="utf-8")
            add_to_index(gmode, world, recovery_slot)
            embedded = vanilla_path / "thumb.png"
            if embedded.exists():
                THUMBS.mkdir(parents=True, exist_ok=True)
                try: shutil.copyfile(embedded, THUMBS / f"{recovery_slot}.png")
                except OSError: pass
            log(f"Crash recovery: {slot} -> {recovery_slot}")
            recovered.append(recovery_slot)
        else:
            log(f"Crash recovery: copy failed for {slot}")
        if vanilla_path.is_dir():
            shutil.rmtree(vanilla_path, ignore_errors=True)
        remove_vanilla_owned(gmode, slot, sid)
    if recovered:
        crash_log.write_text("\n".join(recovered) + "\n", encoding="utf-8")
        log(f"{len(recovered)} crash recovery save(s) ready.")

invoke_crash_recovery()

# ---- Phase 2d.4 — IMPORT (queue-based, multi-entry) -------------------------

def op_import(*_):
    """Imports native PZ saves from SAVES into BACKUPS as standalone slots.
    The Lua side prepares ManualSave_ImportQueue.txt with one 'gmode|world'
    line per save the user picked; we process them all in one pass."""
    import_queue = LuaDir / "ManualSave_ImportQueue.txt"
    if not import_queue.exists():
        log("IMPORT: queue file not found.")
        write_done("ERROR", "IMPORT", {"ERROR": "queue_not_found"})
        return
    import_date = datetime.now().strftime("%d %b %Y %H:%M")
    try:
        queue_lines = import_queue.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        queue_lines = []
    for line in queue_lines:
        parts = line.rstrip("\r\n").split("|", 1)
        if len(parts) < 2: continue
        ig = parts[0].strip()
        iw = parts[1].strip()
        if not ig or not iw: continue
        src = SAVES   / ig / iw
        dst = BACKUPS / ig / iw / iw   # NB: world reused as slot name on import
        if not src.is_dir():
            log(f"IMPORT: source not found: {src}")
            continue
        log(f"IMPORT: '{iw}' (gmode={ig}) -> {dst}")
        if not copy_tree_merge(src, dst):
            continue
        mods_str = ""
        mods_file = src / "mods.txt"
        if mods_file.exists():
            try:
                mods_str = ", ".join(
                    ln.strip()
                    for ln in mods_file.read_text(encoding="utf-8", errors="replace").splitlines()
                    if ln.strip()
                )
            except OSError: pass
        sz   = folder_size_mb(dst)
        meta = LuaDir / f"ManualSaves_Meta_{_safe_name(ig)}_{_safe_name(iw)}_{_safe_name(iw)}.txt"
        meta.write_text("\n".join([
            f"DATE={import_date}",
            "TYPE=NATIVE",
            f"GMODE={ig}",
            f"WORLD={iw}",
            f"SLOT={iw}",
            "MAP=",
            f"MODS={mods_str}",
            f"SIZE={sz} MB",
            "SOURCE=NATIVE",
        ]) + "\n", encoding="utf-8")
        log(f"IMPORT: meta written for '{iw}' (size={sz} MB).")
        embedded = dst / "thumb.png"
        if embedded.exists():
            THUMBS.mkdir(parents=True, exist_ok=True)
            try:
                shutil.copyfile(embedded, THUMBS / f"{iw}.png")
                log(f"IMPORT: thumbnail copied for '{iw}'.")
            except OSError: pass
    try: import_queue.unlink()
    except OSError: pass
    update_index()
    write_done("OK", "IMPORT")
    log("IMPORT complete.")

# ---- Phase 2d.3 — core operations: SAVE, LOAD -------------------------------

def _safe_name(s: str) -> str:
    """Meta-file name component: spaces become underscores (mirrors .ps1)."""
    return s.replace(" ", "_")

def _session_id_now() -> str:
    """LOAD session id format matches PowerShell's 'yyyyMMdd_HHmmss_fff'."""
    now = datetime.now()
    return now.strftime("%Y%m%d_%H%M%S_") + f"{now.microsecond // 1000:03d}"

def op_save(p):
    gmode      = p.get("GMODE") or ""
    world      = p.get("WORLD") or ""
    slot       = p.get("SLOT")  or ""
    live_world = p.get("LIVE_WORLD") or world
    src = SAVES   / gmode / live_world
    dst = BACKUPS / gmode / world / slot
    if not src.is_dir():
        log(f"ERROR: save folder not found: {src}")
        write_done("ERROR", "SAVE", {"ERROR": "src_not_found"})
        return
    # PZ keeps writing for a moment after the player triggers a save. Give it
    # a beat to flush unless this is a quick save (which doesn't suffer from
    # the race because PZ writes synchronously for quicksaves).
    if "QUICK_SAVE" not in slot:
        log("Full Save: waiting 1 sec for PZ flush...")
        time.sleep(1.0)
    log(f"Copying: {src} -> {dst}")
    if not copy_tree_merge(src, dst):
        write_done("ERROR", "SAVE", {"ERROR": "copy_failed"})
        return
    log(f"SAVE complete: {dst}")
    add_to_index(gmode, world, slot)
    # Thumb handling — versioned filename so the Lua side can cache-bust.
    THUMBS.mkdir(parents=True, exist_ok=True)
    thumb_ver  = datetime.now().strftime("%Y%m%d%H%M%S")
    thumb_file = f"{slot}_v{thumb_ver}.png"
    for stale in THUMBS.glob(f"{slot}_v*.png"):
        try: stale.unlink()
        except OSError: pass
    embedded_thumb  = dst / "thumb.png"
    versioned_thumb = THUMBS / thumb_file
    if THUMB_PENDING.exists():
        log("Using captured thumbnail.")
        try:
            shutil.copyfile(THUMB_PENDING, embedded_thumb)
            shutil.copyfile(THUMB_PENDING, versioned_thumb)
        except OSError as e:
            log(f"Thumbnail copy failed: {e}")
        try: THUMB_PENDING.unlink()
        except OSError: pass
    else:
        log("No thumbnail, generating placeholder...")
        _make_placeholder_thumb(embedded_thumb)
        try: shutil.copyfile(embedded_thumb, versioned_thumb)
        except OSError: pass
    # Meta-file footer: only append if the Lua side has already created it.
    size      = folder_size_mb(dst)
    date_str  = datetime.now().strftime("%d %b %Y %H:%M")
    meta_path = LuaDir / f"ManualSaves_Meta_{_safe_name(gmode)}_{_safe_name(world)}_{_safe_name(slot)}.txt"
    if meta_path.exists():
        try:
            with meta_path.open("a", encoding="utf-8") as f:
                f.write(f"SIZE={size} MB\n")
                f.write(f"DATE={date_str}\n")
                f.write(f"THUMB_FILE={thumb_file}\n")
            log(f"SIZE={size} MB, DATE={date_str}, THUMB_FILE={thumb_file} written.")
        except OSError as e:
            log(f"Meta write failed: {e}")
    write_done("OK", "SAVE", {"SLOT": slot, "THUMB_FILE": thumb_file})
    # If the game is about to close the session, drop the vanilla mirror.
    if p.get("SESSION_CLOSE") == "1":
        sid = p.get("SESSION_ID")
        if sid and test_vanilla_owned(gmode, slot, sid):
            vp = SAVES / gmode / slot
            if vp.is_dir():
                shutil.rmtree(vp, ignore_errors=True)
            remove_vanilla_owned(gmode, slot, sid)
            log("SESSION_CLOSE: vanilla slot removed.")

def op_load(p):
    gmode = p.get("GMODE") or ""
    world = p.get("WORLD") or ""
    slot  = p.get("SLOT")  or ""
    src = BACKUPS / gmode / world / slot
    if not src.is_dir():
        log(f"ERROR: backup not found: {src}")
        write_done("ERROR", "LOAD", {"ERROR": "backup_not_found"})
        return
    dst = SAVES / gmode / slot
    if not copy_tree_mirror(src, dst):
        write_done("ERROR", "LOAD", {"ERROR": "restore_failed"})
        return
    log(f"RESTORE complete: {dst}")
    session_id = _session_id_now()
    remove_vanilla_owned(gmode, slot)             # purge any stale entry first
    add_vanilla_owned(gmode, world, slot, session_id)
    # Flags file: the Lua side may have queued WIPE_ZOMBIES (and other future
    # flags) for the watcher to honour before PZ reads the save back in.
    safe_slot  = re.sub(r"[\\/ ]", "_", slot)
    flags_file = LuaDir / f"ManualSaves_Flags_{safe_slot}.txt"
    if flags_file.exists():
        log("Found flags file!")
        flags = ""
        try:
            for ln in flags_file.read_text(encoding="utf-8", errors="replace").splitlines():
                m = re.match(r"^FLAGS=(.*)$", ln)
                if m:
                    flags = m.group(1)
                    break
        except OSError: pass
        if "WIPE_ZOMBIES" in flags:
            log("Wiping zombies (zpop files)...")
            zpop_dir = dst / "zpop"
            if zpop_dir.is_dir():
                for zf in zpop_dir.glob("zpop_*.bin"):
                    try: zf.unlink()
                    except OSError: pass
            log("Zombie wipe complete.")
        # Pass any remaining flags through to the Lua side via PostLoad file.
        post_flags = ",".join(f for f in flags.split(",") if f and f != "WIPE_ZOMBIES")
        if post_flags:
            (LuaDir / "ManualSaves_PostLoad.txt").write_text(f"FLAGS={post_flags}\n", encoding="utf-8")
            log(f"Post-load flags written: {post_flags}")
        try: flags_file.unlink()
        except OSError: pass
    write_done("OK", "LOAD", {"SLOT": slot, "SESSION_ID": session_id})

# ---- Phase 2d.2 — file management operations --------------------------------

def _resolve_old_new_slot(p):
    """Lua may pass OLD_SLOT/NEW_SLOT as separate keys or packed into SLOT
    as 'OLD|NEW'. Both encodings appear in the .ps1, so accept either."""
    old_slot = p.get("OLD_SLOT") or ""
    new_slot = p.get("NEW_SLOT") or ""
    if not old_slot or not new_slot:
        slot = p.get("SLOT") or ""
        if "|" in slot:
            a, b = slot.split("|", 1)
            old_slot = old_slot or a
            new_slot = new_slot or b
    return old_slot, new_slot

def op_rename(p):
    gmode = p.get("GMODE") or ""
    world = p.get("WORLD") or ""
    old_slot, new_slot = _resolve_old_new_slot(p)
    src = BACKUPS / gmode / world / old_slot
    if not src.is_dir():
        log(f"RENAME ERROR: source not found: {src}")
        write_done("ERROR", "RENAME", {"ERROR": "source_not_found"})
        return
    dst = BACKUPS / gmode / world / new_slot
    try:
        src.rename(dst)
    except OSError as e:
        log(f"RENAME failed: {e}")
        write_done("ERROR", "RENAME", {"ERROR": "rename_failed"})
        return
    old_thumb = THUMBS / f"{old_slot}.png"
    if old_thumb.exists():
        try: old_thumb.rename(THUMBS / f"{new_slot}.png")
        except OSError: pass
    update_index()
    write_done("OK", "RENAME", {"SLOT": new_slot})

def op_clone(p):
    gmode = p.get("GMODE") or ""
    world = p.get("WORLD") or ""
    old_slot, new_slot = _resolve_old_new_slot(p)
    src = BACKUPS / gmode / world / old_slot
    if src.is_dir():
        copy_tree_merge(src, BACKUPS / gmode / world / new_slot)
    update_index()
    copy_thumb_for_clone(gmode, world, old_slot, new_slot)
    write_done("OK", "CLONE", {
        "SLOT": new_slot,
        "DATE": datetime.now().strftime("%d %b %Y %H:%M"),
    })

def op_clone_mods(p):
    gmode = p.get("GMODE") or ""
    world = p.get("WORLD") or ""
    old_slot, new_slot = _resolve_old_new_slot(p)
    mod_list = p.get("MODS") or ""
    src = BACKUPS / gmode / world / old_slot
    if not src.is_dir():
        log(f"CLONE_MODS: source not found: {src}")
        write_done("ERROR", "CLONE_MODS", {"ERROR": "source_not_found"})
        return
    dst = BACKUPS / gmode / world / new_slot
    if not copy_tree_merge(src, dst):
        write_done("ERROR", "CLONE_MODS", {"ERROR": "copy_failed"})
        return
    mod_lines = [f"mod={m.strip()}" for m in mod_list.split(",") if m.strip()]
    (dst / "mods.txt").write_text("\n".join(mod_lines) + ("\n" if mod_lines else ""), encoding="utf-8")
    log(f"CLONE_MODS: mods.txt written with {len(mod_lines)} mods.")
    update_index()
    copy_thumb_for_clone(gmode, world, old_slot, new_slot)
    write_done("OK", "CLONE_MODS", {"SLOT": new_slot})

def op_export_vanilla(p):
    gmode = p.get("GMODE") or ""
    world = p.get("WORLD") or ""
    slot  = p.get("SLOT")  or ""
    export_name = p.get("EXPORT_NAME") or f"{slot}_exported"
    src = BACKUPS / gmode / world / slot
    if not src.is_dir():
        log(f"EXPORT_VANILLA: source not found: {src}")
        write_done("ERROR", "EXPORT_VANILLA", {"ERROR": "source_not_found"})
        return
    dst = SAVES / gmode / export_name
    if not copy_tree_merge(src, dst):
        write_done("ERROR", "EXPORT_VANILLA", {"ERROR": "copy_failed"})
        return
    # The .ps1 crops the thumb to 250x250 via System.Drawing here. The Pillow
    # equivalent is straightforward but adds a non-stdlib dependency we want
    # to avoid for the watcher. The full-size thumb still works as an export
    # preview; Phase 3 can revisit if needed.
    log(f"EXPORT_VANILLA: {slot} -> {dst}")
    write_done("OK", "EXPORT_VANILLA")

# ---- Phase 2d.1 — simple operations -----------------------------------------

def op_session_end(p):
    sid   = p.get("SESSION_ID")
    gmode = p.get("GMODE") or ""
    slot  = p.get("SLOT")  or ""
    if sid and test_vanilla_owned(gmode, slot, sid):
        vp = SAVES / gmode / slot
        if vp.is_dir():
            shutil.rmtree(vp, ignore_errors=True)
        remove_vanilla_owned(gmode, slot, sid)
        log("SESSION_END: vanilla slot removed.")
    write_done("OK", "SESSION_END")

def op_scan_vanilla(*_):
    scan_result = LuaDir / "ManualSave_VanillaScan.txt"
    lines = []
    if SAVES.is_dir():
        for g in sorted(c for c in SAVES.iterdir() if c.is_dir() and not c.name.startswith("MSM_")):
            for w in sorted(c for c in g.iterdir() if c.is_dir()):
                imported = "1" if (BACKUPS / g.name / w.name / w.name).is_dir() else "0"
                try:
                    fdate = datetime.fromtimestamp(w.stat().st_mtime).strftime("%m/%d/%Y %H:%M")
                except OSError:
                    fdate = ""
                total = 0
                for root, _, files in os.walk(w):
                    for fn in files:
                        try: total += (Path(root) / fn).stat().st_size
                        except OSError: pass
                size_mb = round(total / (1024 * 1024)) if total > 0 else 0
                lines.append(f"{g.name}|{w.name}|{fdate}|{imported}|{size_mb}")
    lines.append("##SCAN_DONE##")
    scan_result.write_text("\n".join(lines) + "\n", encoding="utf-8")
    write_done("OK", "SCAN_VANILLA")
    log("SCAN_VANILLA complete.")

def op_rename_world(p):
    gmode     = p.get("GMODE") or ""
    old_world = p.get("OLD_WORLD") or p.get("WORLD") or ""
    new_world = p.get("NEW_WORLD") or ""
    slot      = p.get("SLOT") or ""
    # Fallback used by Lua: NEW_WORLD encoded as the second half of SLOT="OLD|NEW".
    if not new_world and "|" in slot:
        new_world = slot.split("|", 1)[1]
    if old_world and new_world:
        src = BACKUPS / gmode / old_world
        if src.is_dir():
            try:
                src.rename(BACKUPS / gmode / new_world)
            except OSError as e:
                log(f"RENAME_WORLD failed: {e}")
    update_index()
    write_done("OK", "RENAME_WORLD")

def op_delete(p):
    gmode = p.get("GMODE") or ""
    world = p.get("WORLD") or ""
    slot  = p.get("SLOT")  or ""
    target = BACKUPS / gmode / world / slot
    if target.is_dir():
        shutil.rmtree(target, ignore_errors=True)
    # Remove slot thumbs (both the plain name and the versioned set).
    plain = THUMBS / f"{slot}.png"
    if plain.exists():
        try: plain.unlink()
        except OSError: pass
    if THUMBS.is_dir():
        for thumb in THUMBS.glob(f"{slot}_v*.png"):
            try: thumb.unlink()
            except OSError: pass
    # Prune empty parent dirs (world first, then gmode), matching the .ps1.
    world_dir = BACKUPS / gmode / world
    if world_dir.is_dir() and not any(world_dir.iterdir()):
        try: world_dir.rmdir()
        except OSError: pass
    gmode_dir = BACKUPS / gmode
    if gmode_dir.is_dir() and not any(gmode_dir.iterdir()):
        try: gmode_dir.rmdir()
        except OSError: pass
    # If the slot was mod-tracked as vanilla-owned, nuke the vanilla folder too.
    if test_vanilla_owned(gmode, slot):
        vanilla_slot = SAVES / gmode / slot
        if vanilla_slot.is_dir():
            shutil.rmtree(vanilla_slot, ignore_errors=True)
            log(f"DELETE: vanilla save removed: {vanilla_slot}")
        remove_vanilla_owned(gmode, slot)
        vanilla_gmode = SAVES / gmode
        if vanilla_gmode.is_dir() and not any(vanilla_gmode.iterdir()):
            try: vanilla_gmode.rmdir()
            except OSError: pass
    update_index()
    write_done("OK", "DELETE")

DISPATCH = {
    "SAVE":           op_save,
    "LOAD":           op_load,
    "SESSION_END":    op_session_end,
    "DELETE":         op_delete,
    "EXPORT_VANILLA": op_export_vanilla,
    "RENAME":         op_rename,
    "CLONE":          op_clone,
    "RENAME_WORLD":   op_rename_world,
    "CLONE_MODS":     op_clone_mods,
    "SCAN_VANILLA":   op_scan_vanilla,
    "IMPORT":         op_import,
}

# ---------------------------------------------------------------------------
# Screenshot stub. Real port is Phase 3 (option A/B/C still to be picked).
# For now we just acknowledge the request with a placeholder thumbnail so
# the SAVE pipeline can complete end-to-end during testing.
# ---------------------------------------------------------------------------
def _make_placeholder_thumb(dst: Path) -> None:
    """Pick a random PNG/JPG from placeholders/ if available, else write an
    empty 1-byte file. PIL/Pillow aren't stdlib so we deliberately don't
    transcode JPGs into PNGs here — Phase 3 handles real screenshots."""
    if PLACEHOLDER_DIR.is_dir():
        images = [p for p in PLACEHOLDER_DIR.iterdir() if p.suffix.lower() in (".png", ".jpg", ".jpeg")]
        if images:
            import random
            pick = random.choice(images)
            try:
                shutil.copyfile(pick, dst)
                return
            except OSError:
                pass
    try:
        dst.write_bytes(b"")
    except OSError:
        pass

def handle_screenshot_request() -> None:
    log("Screenshot request received (stub: copying random placeholder).")
    try: SCREEN_REQ.unlink()
    except OSError: pass
    if THUMB_PENDING.exists():
        try: THUMB_PENDING.unlink()
        except OSError: pass
    _make_placeholder_thumb(THUMB_PENDING)
    SCREEN_DONE.write_text("DONE\n", encoding="utf-8")
    log("Screenshot placeholder ready.")

# ---------------------------------------------------------------------------
# Main polling loop. Same cadence as the .ps1 (100ms). Screenshot has higher
# priority than the signal queue so a SAVE issued right after a screenshot
# request still finds the thumb on disk.
# ---------------------------------------------------------------------------
log("Watching for signals... (press Ctrl+C to stop)")
print()

while True:
    time.sleep(0.1)
    _heartbeat_tick()

    if SCREEN_REQ.exists():
        handle_screenshot_request()
        continue

    if not SIGNAL.exists():
        continue

    params = read_signal(SIGNAL)
    try: SIGNAL.unlink()
    except OSError: pass

    action = (params.get("ACTION") or "").upper()
    if not action:
        continue
    log(f"Signal: {action} {params.get('GMODE','')} {params.get('WORLD','')} {params.get('SLOT','')}")

    handler = DISPATCH.get(action)
    if handler is None:
        log(f"Unknown action: {action}")
        write_done("ERROR", action, {"ERROR": "unknown_action"})
        continue

    try:
        handler(params)
    except Exception as e:
        log(f"Handler {action} crashed: {e!r}")
        write_done("ERROR", action, {"ERROR": "handler_crash"})

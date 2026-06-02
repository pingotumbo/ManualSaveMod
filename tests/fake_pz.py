#!/usr/bin/env python3
# =============================================================================
# fake_pz.py - mini PZ simulator for ManualSave_Watcher
# =============================================================================
# Spawns the Linux/macOS watcher against a throwaway temporary Zomboid root,
# fires each operation in turn, validates the Done file replies, then tears
# everything down. Designed to run on Linux (WSL/SteamDeck/macOS) or directly
# on Windows for development - the watcher's stdlib is cross-platform.
#
# Usage:
#   python3 tests/fake_pz.py
#
# Exit code: 0 on success, 1 if any check failed.
# =============================================================================

import os
import sys
import time
import shutil
import tempfile
import subprocess
from pathlib import Path

REPO_ROOT  = Path(__file__).resolve().parent.parent
WATCHER_PY = REPO_ROOT / "Contents" / "mods" / "ManualSaveMod" / "Linux" / "ManualSave_Watcher.py"

# ---------------------------------------------------------------------------
# Test environment helpers.
# ---------------------------------------------------------------------------
def make_tmp_root() -> Path:
    root = Path(tempfile.mkdtemp(prefix="msm-fake-pz-"))
    (root / "Saves").mkdir()
    return root

def ensure_backup_slot(tmp_root: Path, gmode: str, world: str, slot: str) -> Path:
    """Create a minimal backup folder so ops that demand a source can run."""
    d = tmp_root / "ManualSaves" / gmode / world / slot
    d.mkdir(parents=True, exist_ok=True)
    (d / "thumb.png").write_bytes(b"\x89PNG\r\n")   # not a valid PNG, fine for tests
    (d / "map_p.bin").write_bytes(b"dummy")
    return d

def ensure_vanilla_world(tmp_root: Path, gmode: str, world: str) -> Path:
    """Create a minimal vanilla save folder so SAVE has a source to copy."""
    d = tmp_root / "Saves" / gmode / world
    d.mkdir(parents=True, exist_ok=True)
    (d / "map.bin").write_bytes(b"world data")
    (d / "zpop").mkdir(exist_ok=True)
    (d / "zpop" / "zpop_0_0.bin").write_bytes(b"zombie pop")
    return d

def stage_watcher(tmp_root: Path) -> Path:
    """Copy the production watcher into a staging dir under tmp_root and drop
    a UserDir.txt next to it so the watcher resolves ZomboidRoot to tmp_root.
    We never touch the real Linux/ManualSave_UserDir.txt."""
    staging = tmp_root / "_watcher"
    staging.mkdir()
    shutil.copyfile(WATCHER_PY, staging / "ManualSave_Watcher.py")
    (staging / "ManualSave_UserDir.txt").write_text(
        str(tmp_root) + "\n", encoding="utf-8"
    )
    return staging / "ManualSave_Watcher.py"

def spawn_watcher(staged_py: Path) -> subprocess.Popen:
    return subprocess.Popen(
        [sys.executable, str(staged_py)],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, bufsize=1,
    )

def kill_watcher(proc: subprocess.Popen) -> None:
    try:
        if sys.platform == "win32":
            subprocess.run(
                ["taskkill", "/PID", str(proc.pid), "/F"],
                capture_output=True, timeout=5,
            )
        else:
            proc.terminate()
            try: proc.wait(timeout=3)
            except subprocess.TimeoutExpired: proc.kill()
    except (subprocess.SubprocessError, OSError):
        try: proc.kill()
        except OSError: pass

# ---------------------------------------------------------------------------
# Signal protocol helpers (the Lua side of PZ does the same thing in-game).
# ---------------------------------------------------------------------------
def wait_for_heartbeat(tmp_root: Path, timeout: float = 5.0) -> bool:
    hb = tmp_root / "Lua" / "ManualSave_Heartbeat.txt"
    t0 = time.time()
    while time.time() - t0 < timeout:
        if hb.exists():
            try:
                if int(hb.read_text(encoding="ascii").strip()) > 0:
                    return True
            except (OSError, ValueError):
                pass
        time.sleep(0.05)
    return False

def clear_done(tmp_root: Path) -> None:
    done = tmp_root / "Lua" / "ManualSave_Done.txt"
    if done.exists():
        try: done.unlink()
        except OSError: pass

def write_signal(tmp_root: Path, params: dict) -> None:
    sig = tmp_root / "Lua" / "ManualSave_Signal.txt"
    sig.write_text(
        "\n".join(f"{k}={v}" for k, v in params.items()) + "\n",
        encoding="utf-8",
    )

def wait_for_done(tmp_root: Path, timeout: float = 5.0):
    done = tmp_root / "Lua" / "ManualSave_Done.txt"
    t0 = time.time()
    while time.time() - t0 < timeout:
        if done.exists():
            try:
                parsed = {}
                for ln in done.read_text(encoding="utf-8", errors="replace").splitlines():
                    if "=" in ln:
                        k, v = ln.split("=", 1)
                        parsed[k.strip()] = v.strip()
                try: done.unlink()
                except OSError: pass
                return parsed
            except OSError:
                pass
        time.sleep(0.05)
    return None

def run_op(tmp_root: Path, action: str, extra: dict, expected_status: str):
    clear_done(tmp_root)
    write_signal(tmp_root, {"ACTION": action, **extra})
    reply = wait_for_done(tmp_root)
    if reply is None:
        return False, "timeout waiting for Done file"
    if reply.get("STATUS") != expected_status:
        return False, f"expected STATUS={expected_status}, got {reply.get('STATUS')!r}"
    if reply.get("ACTION") != action:
        return False, f"expected ACTION={action}, got {reply.get('ACTION')!r}"
    return True, "OK"

# ---------------------------------------------------------------------------
# Test matrix. In Phase 2b every real op replies NOT_IMPLEMENTED. As Phase 2d
# ports each op for real, flip its expected_status to OK and add post-checks
# (e.g. assert SAVE produced the expected backup folder).
# ---------------------------------------------------------------------------
OPS_TO_TEST = [
    # action            extra params                                                                    expected
    # Use QUICK_SAVE in slot name to skip the 1s PZ-flush delay on SAVE.
    ("SAVE",           {"GMODE":"sandbox","WORLD":"test","SLOT":"QUICK_SAVE_slot1"},                   "OK"),
    ("LOAD",           {"GMODE":"sandbox","WORLD":"test","SLOT":"QUICK_SAVE_slot1"},                   "OK"),
    ("SESSION_END",    {"GMODE":"sandbox","SLOT":"QUICK_SAVE_slot1","SESSION_ID":"abc123"},            "OK"),
    ("DELETE",         {"GMODE":"sandbox","WORLD":"test","SLOT":"QUICK_SAVE_slot1"},                   "OK"),
    ("EXPORT_VANILLA", {"GMODE":"sandbox","WORLD":"test","SLOT":"slotE"},                              "OK"),
    ("RENAME",         {"GMODE":"sandbox","WORLD":"test","OLD_SLOT":"slotR","NEW_SLOT":"slotR2"},      "OK"),
    ("CLONE",          {"GMODE":"sandbox","WORLD":"test","OLD_SLOT":"slotC","NEW_SLOT":"slotC2"},      "OK"),
    ("RENAME_WORLD",   {"GMODE":"sandbox","OLD_WORLD":"worldA","NEW_WORLD":"worldB"},                  "OK"),
    ("CLONE_MODS",     {"GMODE":"sandbox","WORLD":"test","OLD_SLOT":"slotM","NEW_SLOT":"slotM2","MODS":"modX, modY"}, "OK"),
    ("SCAN_VANILLA",   {},                                                                              "OK"),
    ("IMPORT",         {},                                                                              "OK"),
    # Bonus: unknown actions must reply ERROR (so a corrupted signal doesn't hang PZ).
    ("BOGUS_OPERATION",{},                                                                              "ERROR"),
]

# ---------------------------------------------------------------------------
# Main.
# ---------------------------------------------------------------------------
def main() -> int:
    if not WATCHER_PY.exists():
        print(f"[fake_pz] ERROR: watcher not found at {WATCHER_PY}")
        return 1
    print(f"[fake_pz] watcher: {WATCHER_PY}")

    tmp_root = make_tmp_root()
    print(f"[fake_pz] tmp root: {tmp_root}")
    staged_py = stage_watcher(tmp_root)
    proc = spawn_watcher(staged_py)
    print(f"[fake_pz] watcher PID: {proc.pid}")

    try:
        if not wait_for_heartbeat(tmp_root):
            print("[fake_pz] FAIL: watcher did not heartbeat within 5s")
            return 1
        print("[fake_pz] heartbeat OK, staging source folders for happy-path ops")

        # Source folders for ops that need a real backup to operate on.
        ensure_vanilla_world(tmp_root, "sandbox", "test")           # SAVE source
        ensure_backup_slot(tmp_root, "sandbox", "test", "slotE")    # EXPORT_VANILLA
        ensure_backup_slot(tmp_root, "sandbox", "test", "slotR")    # RENAME
        ensure_backup_slot(tmp_root, "sandbox", "test", "slotC")    # CLONE
        ensure_backup_slot(tmp_root, "sandbox", "test", "slotM")    # CLONE_MODS
        ensure_backup_slot(tmp_root, "sandbox", "worldA", "any")    # RENAME_WORLD (needs world dir, slot inside is fine)

        # IMPORT: stage a queue file with one entry + a vanilla source folder.
        imported_world = ensure_vanilla_world(tmp_root, "sandbox", "imported_world")
        (imported_world / "mods.txt").write_text("ModAlpha\nModBeta\n", encoding="utf-8")
        (tmp_root / "Lua" / "ManualSave_ImportQueue.txt").write_text("sandbox|imported_world\n", encoding="utf-8")
        print("[fake_pz] staged, exercising operations\n")

        results = []
        for action, extras, expected in OPS_TO_TEST:
            ok, msg = run_op(tmp_root, action, extras, expected)
            tag = "PASS" if ok else "FAIL"
            print(f"  [{tag}] {action:18s} -> {msg}")
            results.append(ok)

        n_pass  = sum(results)
        n_total = len(results)
        print(f"\n[fake_pz] {n_pass}/{n_total} tests passed")
        return 0 if n_pass == n_total else 1
    finally:
        kill_watcher(proc)
        time.sleep(0.3)
        try: shutil.rmtree(tmp_root)
        except OSError as e: print(f"[fake_pz] cleanup warning: {e}")

if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Stage, install or restore the local Horizon Base build. Python standard library only."""
from __future__ import annotations
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import zipfile

PROJECT = Path(__file__).resolve().parents[1]
VERSION = "0.4.0"
OWNED = ("HorizonBase.lua", "lib/horizonbase", "resource/horizonbase")
RESOURCE_GROUPS = ("fonts", "sa_map", "weaponicons", "mapicons")
UI_ASSETS = "resource/horizonbase/ui-v0212"
HUD_ASSETS = "resource/horizonbase/hud-v0218"
DASH_ASSETS = "resource/horizonbase/dashboard-v031"
VEHICLE_ASSETS = "resource/horizonbase/vehicle-v040"
PORTRAIT_ASSETS = "resource/horizonbase/portraits-v0222"
NATIVE_ASSETS = "resource/horizonbase/native-v0232"


def verify_target(root: Path) -> None:
    for relative in ("lib/moonloader.lua", "lib/mimgui/init.lua", "lib/samp/events.lua"):
        if not (root / relative).is_file():
            raise ValueError(f"This MoonLoader install is missing {relative}: {root}")
    if not (root.parent / "SAMPFUNCS.asi").is_file():
        raise ValueError("SAMPFUNCS.asi is missing from the game's root directory.")


def require_game_closed() -> None:
    if os.name == "nt":
        output = subprocess.run(["tasklist", "/FO", "CSV", "/NH"], capture_output=True, text=True, check=True).stdout.lower()
        if '"gta_sa.exe"' in output or '"samp.exe"' in output:
            raise ValueError("Close SA-MP and GTA before switching script files.")
    else:
        for comm in Path("/proc").glob("[0-9]*/comm"):
            try:
                name = comm.read_text().strip().lower()
            except (OSError, UnicodeError):
                continue
            if name in {"gta_sa.exe", "samp.exe"}:
                raise ValueError("Close SA-MP and GTA before switching script files.")


def files_under(root: Path) -> dict[str, str]:
    return {str(p.relative_to(root)).replace("\\", "/"): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(root.rglob("*")) if p.is_file()}


def stage(target: Path) -> dict:
    verify_target(target)
    output = PROJECT / "build" / "moonloader"
    if output.exists():
        shutil.rmtree(output)
    shutil.copytree(PROJECT / "src", output)
    resource_source = target / "resource" / "lunahz"
    if not resource_source.exists():
        resource_source = target / "resource" / "horizonbase"
    resources = output / "resource" / "horizonbase"
    resources.mkdir(parents=True)
    for group in RESOURCE_GROUPS:
        source = resource_source / group
        if source.is_dir():
            shutil.copytree(source, resources / group)
    for name in ("wantedstar.png", "wantedstar-outline.png"):
        if (resource_source / name).is_file():
            shutil.copy2(resource_source / name, resources / name)
    (output / "THIRD_PARTY.md").write_bytes((PROJECT / "THIRD_PARTY.md").read_bytes())
    ui_assets=output / UI_ASSETS
    ui_assets.mkdir()
    # Licensed UI sources and the approved menu logo live in the repository.
    # Other visual resources come from explicit local preparation or the
    # installed resource set, outside the public source export.
    for directory in (target / UI_ASSETS,PROJECT / '.local/prepared-hud/ui-v0212',PROJECT / 'assets/ui-v0212'):
        if directory.is_dir():
            for source in directory.iterdir():
                if source.is_file() and source.suffix in {".png", ".txt", ".json"}:
                    shutil.copy2(source,ui_assets/source.name)
    logo=PROJECT / "assets/branding/luahz-logo.png"
    if not logo.is_file():logo=PROJECT / "branding/luahz-menu-icon-hz-v4.png"
    if logo.is_file():shutil.copy2(logo,ui_assets/'luahz-logo.png')
    for relative in (HUD_ASSETS,DASH_ASSETS,VEHICLE_ASSETS,PORTRAIT_ASSETS,NATIVE_ASSETS):
        prepared=PROJECT / ".local" / "prepared-hud" / Path(relative).name
        asset_source=prepared if prepared.is_dir() else target / relative
        if asset_source.is_dir():shutil.copytree(asset_source, output / relative)
    manifest = {"build": VERSION, "target": str(target), "staged": str(output),
                "files": files_under(output), "resources_from": str(resource_source),
                "resource_note": "Copied from this local game installation for local QA; excluded from project source."}
    (PROJECT / "build" / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    archive = PROJECT / "build" / "LuaHZ-local-QA.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as package:
        for p in sorted(output.rglob("*")):
            if p.is_file():
                package.write(p, p.relative_to(output))
    return {"staged": str(output), "archive": str(archive), "file_count": len(manifest["files"]),
            "map_tiles": len(list((resources / "sa_map").glob("*.jpg"))) if (resources / "sa_map").exists() else 0}


def install(target: Path) -> dict:
    verify_target(target)
    require_game_closed()
    receipt = target / "config" / "horizonbase-deploy.json"
    if receipt.exists():
        raise ValueError("A Horizon Base deployment already exists. Restore it before installing another build.")
    stage(target)
    build = PROJECT / "build" / "moonloader"
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backup = target.parent / "Horizon Base backups" / stamp
    backup.mkdir(parents=True, exist_ok=False)
    moved, installed = [], []
    try:
        for relative in (*OWNED, "LunaHZ.luac", "LunaHZ.lua"):
            original = target / relative
            if original.exists():
                saved = backup / relative
                saved.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(original), str(saved))
                moved.append(relative)
        for relative in OWNED:
            source, destination = build / relative, target / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            installed.append(relative)
            if source.is_dir():
                shutil.copytree(source, destination)
            else:
                shutil.copy2(source, destination)
        receipt.parent.mkdir(exist_ok=True)
        result = {"version": VERSION, "target": str(target), "backup": str(backup),
                  "moved_original_paths": moved, "installed_paths": installed,
                  "original_preferences_preserved": str(target / "config" / "lunahz.ini")}
        receipt.write_text(json.dumps(result, indent=2) + "\n")
        (backup / "deployment.json").write_text(json.dumps(result, indent=2) + "\n")
        return result
    except Exception:
        for relative in reversed(installed):
            destination = target / relative
            if destination.is_dir():
                shutil.rmtree(destination)
            elif destination.exists():
                destination.unlink()
        for relative in reversed(moved):
            destination = target / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(backup / relative), str(destination))
        raise


def update(target: Path, live: bool = False) -> dict:
    """Replace only our script sources; preserve original backups, assets and preferences."""
    verify_target(target)
    if not live:
        require_game_closed()
    receipt = target / "config" / "horizonbase-deploy.json"
    info = json.loads(receipt.read_text())
    if Path(info["target"]) != target:
        raise ValueError("Deployment receipt belongs to a different game copy.")
    original_backup = Path(info["backup"])
    if original_backup.resolve().parent != (target.parent / "Horizon Base backups").resolve():
        raise ValueError("Deployment backup is outside the expected game backup folder.")
    if not original_backup.is_dir():
        raise ValueError("Original backup is missing; refusing to update without recovery files.")
    stage(target)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    backup = original_backup / "updates" / stamp
    backup.mkdir(parents=True, exist_ok=False)
    moved, copied = [], []
    previous_receipt = receipt.read_bytes()
    (backup / "previous-deployment.json").write_bytes(previous_receipt)
    try:
        # Prepare complete Lua payloads and versioned UI assets. Loaded scripts
        # retain their current Lua state until the player explicitly reloads.
        prepared = backup / "payload"
        paths=list(OWNED[:2])
        # During live updates, add a new versioned folder or keep identical
        # existing files. Never replace a loaded texture.
        for asset_path in (UI_ASSETS,HUD_ASSETS,DASH_ASSETS,VEHICLE_ASSETS,PORTRAIT_ASSETS,NATIVE_ASSETS):
            existing=target / asset_path
            staged=PROJECT / "build" / "moonloader" / asset_path
            if staged.is_dir() and (not existing.exists() or files_under(existing)!=files_under(staged)):
                if live and existing.exists():
                    raise ValueError("Versioned assets changed; close the game before updating existing textures.")
                paths.append(asset_path)
        for relative in paths:
            source = PROJECT / "build" / "moonloader" / relative
            destination = prepared / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            if source.is_dir():
                if relative not in (UI_ASSETS,HUD_ASSETS,DASH_ASSETS,VEHICLE_ASSETS,PORTRAIT_ASSETS,NATIVE_ASSETS) and any(p.is_file() and p.suffix != '.lua' for p in source.rglob('*')):
                    raise ValueError("Source update includes a non-Lua file; use a closed-game installation.")
                shutil.copytree(source, destination)
            else:
                shutil.copy2(source, destination)
        # Commit modules before the entry point with same-filesystem renames.
        for relative in [p for p in (UI_ASSETS,HUD_ASSETS,DASH_ASSETS,VEHICLE_ASSETS,PORTRAIT_ASSETS,NATIVE_ASSETS) if p in paths] + ["lib/horizonbase", "HorizonBase.lua"]:
            old = target / relative
            if old.exists():
                saved = backup / relative
                saved.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(old), str(saved))
                moved.append(relative)
            copied.append(relative)
            source = prepared / relative
            destination = target / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(source), str(destination))
        info["version"] = VERSION
        info["last_update_backup"] = str(backup)
        receipt.write_text(json.dumps(info, indent=2) + "\n")
    except Exception:
        for relative in reversed(copied):
            current = target / relative
            if current.is_dir():
                shutil.rmtree(current)
            elif current.exists():
                current.unlink()
        for relative in moved:
            destination = target / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(backup / relative), str(destination))
        receipt.write_bytes(previous_receipt)
        raise
    return {"version": VERSION, "updated_sources": str(target), "previous_build_backup": str(backup),
            "original_lunahz_backup": str(original_backup), "preferences_preserved": True,
            "script_reload_required": live}


def restore(target: Path) -> dict:
    require_game_closed()
    receipt = target / "config" / "horizonbase-deploy.json"
    info = json.loads(receipt.read_text())
    if Path(info["target"]) != target:
        raise ValueError("Deployment receipt belongs to a different game copy.")
    if any(p not in OWNED for p in info["installed_paths"]) or any(
        p not in (*OWNED, "LunaHZ.lua", "LunaHZ.luac") for p in info["moved_original_paths"]
    ):
        raise ValueError("Deployment receipt contains an unexpected path.")
    backup = Path(info["backup"])
    if backup.resolve().parent != (target.parent / "Horizon Base backups").resolve():
        raise ValueError("Deployment backup is outside the expected game backup folder.")
    if not backup.is_dir():
        raise ValueError("Saved original files are missing.")
    for relative in info["moved_original_paths"]:
        if not (backup / relative).exists():
            raise ValueError(f"Saved original is missing: {relative}")
    for relative in ("LunaHZ.lua", "LunaHZ.luac"):
        if relative in info["moved_original_paths"] and (target / relative).exists():
            raise ValueError(f"An original script already exists at {relative}; resolve this collision first.")
    current = backup / "disabled-horizonbase"
    current.mkdir(exist_ok=False)
    for relative in info["installed_paths"]:
        source = target / relative
        if source.exists():
            destination = current / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(source), str(destination))
    for relative in info["moved_original_paths"]:
        destination = target / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(backup / relative), str(destination))
    shutil.move(str(receipt), str(backup / "restored-deployment.json"))
    return {"restored": str(target), "disabled_build_saved": str(current), "preferences_kept": True}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("stage", "install", "update", "restore", "status"))
    parser.add_argument("--moonloader", required=True, type=Path, help="Actual game MoonLoader folder")
    parser.add_argument("--live", action="store_true", help="Lua source update only; use /hbreload in the game afterward")
    args = parser.parse_args()
    target = args.moonloader.resolve()
    try:
        if args.action == "status":
            result = {"target": str(target), "original_active": (target / "LunaHZ.luac").exists(),
                      "horizon_base_active": (target / "HorizonBase.lua").exists()}
        elif args.action == "update":
            result = update(target, live=args.live)
        else:
            if args.live:
                raise ValueError("--live is supported only for Lua source updates.")
            result = {"stage": stage, "install": install, "update": update, "restore": restore}[args.action](target)
    except (OSError, ValueError, zipfile.BadZipFile) as exc:
        parser.exit(1, f"{exc}\n")
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

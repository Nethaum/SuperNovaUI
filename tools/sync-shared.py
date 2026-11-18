"""
Copies the shared code (Core/ and Panel/, except Config.lua, and Modules/CooldownMacro.lua) from this repository to the WoW Forever addon.

    python tools/sync-shared.py           # copy
    python tools/sync-shared.py --check   # only say whether the two are identical (exit 1 when they are not)

The Forever repository is expected next to this one (../SuperNovaUI-Forever). Edit the shared files here, never there.
"""
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "SuperNovaUI"
TARGET = ROOT.parent / "SuperNovaUI-Forever" / "SuperNovaUI_Forever"
NOT_SHARED = {"Core/Config.lua"}
SHARED_FOLDERS = ["Core", "Panel"]
SHARED_MODULES = ["Modules/CooldownMacro.lua"]  # modules that are the same file in both addons


def shared_files():
    for folder in SHARED_FOLDERS:
        for path in sorted((SOURCE / folder).rglob("*.lua")):
            relative = path.relative_to(SOURCE).as_posix()
            if relative not in NOT_SHARED:
                yield relative

    yield from SHARED_MODULES


def main():
    check = "--check" in sys.argv
    different = []

    for relative in shared_files():
        source, target = SOURCE / relative, TARGET / relative
        if not target.exists() or source.read_bytes() != target.read_bytes():
            different.append(relative)
            if not check:
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, target)

    # files that exist only in the Forever copy of a shared folder are leftovers
    for folder in SHARED_FOLDERS:
        for path in sorted((TARGET / folder).rglob("*.lua")):
            relative = path.relative_to(TARGET).as_posix()
            if relative not in NOT_SHARED and not (SOURCE / relative).exists():
                different.append(f"{relative} (only in Forever)")

    verb = "differ" if check else "updated"
    print(f"{len(different)} shared file(s) {verb}" + (": " + ", ".join(different) if different else ""))
    sys.exit(1 if check and different else 0)


if __name__ == "__main__":
    main()

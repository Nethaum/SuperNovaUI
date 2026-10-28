"""
Builds the release zip for CurseForge (and manual installs).

    python build/package.py

Writes dist/SuperNovaUI-<version>.zip with the two addon folders at the top level, the way they
must be copied into Interface/AddOns:

    SuperNovaUI/              the addon
    !SuperNovaUI_Compat/      loads first, restores removed Blizzard globals

The LICENSE is added to both folders. The version comes from SuperNovaUI/SuperNovaUI.toc.
"""
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ADDON_FOLDERS = ["SuperNovaUI", "!SuperNovaUI_Compat"]
LICENSE = ROOT / "LICENSE"


def read_version() -> str:
    toc = (ROOT / "SuperNovaUI" / "SuperNovaUI.toc").read_text(encoding="utf-8")
    match = re.search(r"^## Version:\s*(\S+)", toc, re.MULTILINE)
    if not match:
        sys.exit("No '## Version:' line in SuperNovaUI.toc")
    return match.group(1)


def main() -> None:
    version = read_version()
    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    target = dist / f"SuperNovaUI-{version}.zip"

    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for folder in ADDON_FOLDERS:
            source = ROOT / folder
            if not (source / f"{folder}.toc").exists():
                sys.exit(f"Missing {folder}/{folder}.toc")
            for path in sorted(source.rglob("*")):
                if path.is_file():
                    archive.write(path, path.relative_to(ROOT).as_posix())
            archive.write(LICENSE, f"{folder}/LICENSE")

    print(f"Built {target}")
    with zipfile.ZipFile(target) as archive:
        for name in archive.namelist():
            print("  ", name)


if __name__ == "__main__":
    main()

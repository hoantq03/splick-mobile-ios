#!/usr/bin/env python3
"""Strip XcodeGen folder refs for local SPM packages and fix missing package backlinks."""

from __future__ import annotations

import re
import sys
from pathlib import Path

SPLICK_CORE_PRODUCTS = frozenset(
    {"Networking", "Storage", "DesignSystem", "Common", "Localization"}
)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: patch-xcodeproj-local-packages.py <project.pbxproj>", file=sys.stderr)
        return 1

    pbx_path = Path(sys.argv[1])
    content = pbx_path.read_text()

    local_refs: dict[str, str] = {}
    for match in re.finditer(
        r"(\w+) /\* XCLocalSwiftPackageReference \"Packages/([^\"]+)\" \*/ = \{\n"
        r"\t\t\tisa = XCLocalSwiftPackageReference;\n"
        r"\t\t\trelativePath = Packages/([^;]+);",
        content,
    ):
        local_refs[match.group(3)] = match.group(1)

    folder_ids: set[str] = set()
    for match in re.finditer(
        r"(\w+) /\* (\w+) \*/ = \{isa = PBXFileReference; lastKnownFileType = folder;"
        r" name = \2; path = Packages/\2; sourceTree = SOURCE_ROOT; \};",
        content,
    ):
        folder_ids.add(match.group(1))

    removed_folders = 0
    for folder_id in folder_ids:
        line_pattern = (
            rf"\t\t{folder_id} /\* \w+ \*/ = "
            rf"\{{isa = PBXFileReference; lastKnownFileType = folder;[^\n]+\n"
        )
        if re.search(line_pattern, content):
            content = re.sub(line_pattern, "", content)
            removed_folders += 1
        content = re.sub(rf"\t\t\t\t{folder_id} /\* \w+ \*/,\n", "", content)

    def package_for_product(product_name: str) -> tuple[str, str] | None:
        if product_name in SPLICK_CORE_PRODUCTS:
            package_name = "SplickCore"
        elif product_name == "SplickDomain":
            package_name = "SplickDomain"
        else:
            package_name = product_name

        package_id = local_refs.get(package_name)
        if not package_id:
            return None
        return package_id, package_name

    dep_pattern = re.compile(
        r"(\t\t(\w+) /\* (\w+) \*/ = \{\n"
        r"\t\t\tisa = XCSwiftPackageProductDependency;\n)"
        r"(\t\t\tproductName = (\w+);\n"
        r"\t\t\};)",
        re.MULTILINE,
    )

    patched_deps = 0

    def patch_dependency(match: re.Match[str]) -> str:
        nonlocal patched_deps
        header, _block_id, _comment, tail, product_name = match.groups()
        if "package =" in match.group(0):
            return match.group(0)

        resolved = package_for_product(product_name)
        if not resolved:
            return match.group(0)

        package_id, package_name = resolved
        patched_deps += 1
        return (
            f"{header}"
            f"\t\t\tpackage = {package_id} /* XCLocalSwiftPackageReference "
            f'"Packages/{package_name}" */;\n'
            f"{tail}"
        )

    content = dep_pattern.sub(patch_dependency, content)
    pbx_path.write_text(content)

    print(
        f"→ Patched {pbx_path.name}: removed {removed_folders} folder refs, "
        f"fixed {patched_deps} local package backlinks"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

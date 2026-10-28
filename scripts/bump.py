#!/usr/bin/env python3
"""Bump version in MARKETING_VERSION / CURRENT_PROJECT_VERSION strings.

Supports:
  --patch     1.27.0 → 1.27.1
  --minor     1.27.0 → 1.28.0  (resets patch)
  --major     1.27.0 → 2.0.0   (resets minor and patch)
"""

import argparse
import re
import sys

PBXPROJ = "Spaceman.xcodeproj/project.pbxproj"

MARKETING_PATTERN = r'(MARKETING_VERSION\s*=\s*)(\d+)\.(\d+)\.(\d+)(;)'
CURRENT_PATTERN = r'(CURRENT_PROJECT_VERSION\s*=\s*)(\d+)\.(\d+)\.(\d+)(;)'


def extract_versions(text):
    """Extract all version values and check they are identical."""
    marketing_versions = re.findall(r'MARKETING_VERSION\s*=\s*(\d+\.\d+\.\d+);', text)
    current_versions = re.findall(r'CURRENT_PROJECT_VERSION\s*=\s*(\d+\.\d+\.\d+);', text)

    all_versions = set(marketing_versions + current_versions)

    if len(all_versions) == 0:
        print("ERROR: No versions found in project file", file=sys.stderr)
        sys.exit(1)

    if len(all_versions) > 1:
        print("ERROR: Version mismatch detected!", file=sys.stderr)
        print(f"  MARKETING_VERSION values: {marketing_versions}", file=sys.stderr)
        print(f"  CURRENT_PROJECT_VERSION values: {current_versions}", file=sys.stderr)
        print("Please fix the version inconsistency before bumping.", file=sys.stderr)
        sys.exit(1)

    return all_versions.pop()


def bump_patch(major, minor, patch):
    return major, minor, patch + 1


def bump_minor(major, minor, patch):
    return major, minor + 1, 0


def bump_major(major, minor, patch):
    return major + 1, 0, 0


MODES = {
    "patch": bump_patch,
    "minor": bump_minor,
    "major": bump_major,
}


def make_replacer(bump_func):
    def replacer(match):
        prefix = match.group(1)
        major = int(match.group(2))
        minor = int(match.group(3))
        patch = int(match.group(4))
        suffix = match.group(5)
        new_major, new_minor, new_patch = bump_func(major, minor, patch)
        return f"{prefix}{new_major}.{new_minor}.{new_patch}{suffix}"
    return replacer


def main():
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--patch", action="store_const", dest="mode", const="patch")
    group.add_argument("--minor", action="store_const", dest="mode", const="minor")
    group.add_argument("--major", action="store_const", dest="mode", const="major")
    args = parser.parse_args()

    text = open(PBXPROJ, newline="").read()

    current_version = extract_versions(text)
    print(f"Current version: {current_version}")

    bump_func = MODES[args.mode]
    replacer = make_replacer(bump_func)

    new_text = re.sub(MARKETING_PATTERN, replacer, text)
    new_text = re.sub(CURRENT_PATTERN, replacer, new_text)

    new_version = extract_versions(new_text)
    print(f"New version: {new_version}")

    open(PBXPROJ, "w", newline="").write(new_text)


if __name__ == "__main__":
    main()

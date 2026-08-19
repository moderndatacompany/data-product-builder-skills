#!/usr/bin/env python3
"""
Vendors this repo's skills/ and dpbs-docs/ into the Python package's data/
directory, mirroring what bin/create.js ships in the npm package and what
scripts/prepack-clean-examples.sh prunes before `npm pack`.

Run this before building/testing the Python package (analogous to npm's
automatic "prepack" hook — there's no such lifecycle hook in setuptools, so
it's invoked manually / via the Makefile-style helper here).
"""
import shutil
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
PKG_DATA = Path(__file__).resolve().parents[1] / "src" / "dataproduct_builder_skills" / "data"

ALLOWED_ENGINES = ["databricks", "fabric", "mssql", "postgres", "snowflake", "spark", "trino"]
PRUNE_NAMES = [
    ".gitignore",
    "README.md",
    "*.md",
    "*.csv",
    "*.tsv",
    "config.yaml",
    "domain-resource.yaml",
    "domain_resource.yaml",
    "usage.yaml",
    "package-lock.json",
    "requirements.txt",
    "limitations.yaml",
    "usecases.yaml",
]

# dataos is sparse-checked-out to only this subpath in the source repo.
SRC_SUBPATH_OVERRIDES = {"dataos": ["documentation", "references", "resources", "vulcan"]}
DEST_NAME_OVERRIDES = {"dataos": "vulcan-docs"}


def matches_prune_name(name, patterns):
    for pattern in patterns:
        if pattern.startswith("*."):
            if name.endswith(pattern[1:]):
                return True
        elif name == pattern:
            return True
    return False


def clean_disallowed_files(root: Path, patterns):
    for path in sorted(root.rglob("*"), reverse=True):
        if path.is_dir():
            if not any(path.iterdir()):
                path.rmdir()
        elif matches_prune_name(path.name, patterns):
            path.unlink()


def copy_tree(src: Path, dest: Path, ignore_git=True):
    if dest.exists():
        shutil.rmtree(dest)
    ignore = shutil.ignore_patterns(".git") if ignore_git else None
    shutil.copytree(src, dest, ignore=ignore)


def main():
    if PKG_DATA.exists():
        shutil.rmtree(PKG_DATA)
    PKG_DATA.mkdir(parents=True)

    # skills/
    skills_src = REPO_ROOT / "skills"
    skills_dest = PKG_DATA / "skills"
    copy_tree(skills_src, skills_dest)
    for skill_dir in sorted(skills_dest.iterdir()):
        print(f"  vendored skills/{skill_dir.name}/")

    # dpbs-docs/ (non-examples dirs + loose files, e.g. the .whl)
    docs_src = REPO_ROOT / "dpbs-docs"
    docs_dest = PKG_DATA / "dpbs-docs"
    docs_dest.mkdir(parents=True, exist_ok=True)

    for entry in sorted(docs_src.iterdir()):
        if not entry.is_dir() or entry.name == "vulcan-examples":
            continue
        dest_name = DEST_NAME_OVERRIDES.get(entry.name, entry.name)
        subpath = SRC_SUBPATH_OVERRIDES.get(entry.name, [])
        src = entry.joinpath(*subpath)
        dest = docs_dest / dest_name
        copy_tree(src, dest)
        n = sum(1 for p in dest.rglob("*") if p.is_file())
        print(f"  vendored dpbs-docs/{dest_name}/  ({n} files)")

    for entry in sorted(docs_src.iterdir()):
        if entry.is_file():
            shutil.copyfile(entry, docs_dest / entry.name)
            print(f"  vendored dpbs-docs/{entry.name}")

    # dpbs-docs/vulcan-examples/ — allowed engines only, pruned of junk files
    examples_src = docs_src / "vulcan-examples"
    if examples_src.exists():
        examples_dest = docs_dest / "vulcan-examples"
        examples_dest.mkdir(parents=True, exist_ok=True)
        for engine in ALLOWED_ENGINES:
            src = examples_src / engine
            if not src.exists():
                continue
            dest = examples_dest / engine
            copy_tree(src, dest)
            clean_disallowed_files(dest, PRUNE_NAMES)
            n = sum(1 for p in dest.rglob("*") if p.is_file())
            print(f"  vendored dpbs-docs/vulcan-examples/{engine}/  ({n} files)")

    print("done.")


if __name__ == "__main__":
    sys.exit(main())

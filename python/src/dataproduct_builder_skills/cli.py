#!/usr/bin/env python3
"""Scaffolds Vulcan/DataOS agent skills + docs into the current project.

Python port of bin/create.js — same behavior, same prompts, same output
layout, so it can be run via `uvx`/`pipx run` alongside the npm package's
`npx` flow.
"""
import shutil
import sys
from pathlib import Path

RESET, GREEN, CYAN, YELLOW, BOLD, DIM, RED = (
    "\x1b[0m", "\x1b[32m", "\x1b[36m", "\x1b[33m", "\x1b[1m", "\x1b[2m", "\x1b[31m",
)


def log(msg=""):
    print(msg)


def ok(msg):
    log(f"  {GREEN}✓{RESET}  {msg}")


def info(msg):
    log(f"  {CYAN}→{RESET}  {msg}")


def warn(msg):
    log(f"  {YELLOW}!{RESET}  {msg}")


def err(msg):
    log(f"  {RED}✗{RESET}  {msg}")


DATA_DIR = Path(__file__).resolve().parent / "data"

ALLOWED_ENGINES = ["databricks", "fabric", "mssql", "postgres", "snowflake", "spark", "trino"]

IDE_OPTIONS = [
    ("Cursor", ".cursor"),
    ("Claude Code", ".claude"),
    ("Codex", ".codex"),
    ("VS Code (Copilot)", ".github"),
]


def sync_dir(src: Path, dest: Path):
    """Mirrors src into dest — copies/overwrites everything, and deletes any
    dest entry no longer present in src."""
    dest.mkdir(parents=True, exist_ok=True)
    src_names = {p.name for p in src.iterdir()}

    for entry in dest.iterdir():
        if entry.name not in src_names or entry.name == ".git":
            if entry.is_dir():
                shutil.rmtree(entry)
            else:
                entry.unlink()

    for entry in src.iterdir():
        if entry.name == ".git":
            continue
        d = dest / entry.name
        if entry.is_dir():
            sync_dir(entry, d)
        else:
            shutil.copyfile(entry, d)


def count_files(d: Path) -> int:
    return sum(1 for p in d.rglob("*") if p.is_file())


def rewrite_path_references(d: Path, old: str, new: str):
    for p in d.rglob("*.md"):
        content = p.read_text(encoding="utf-8")
        if old in content:
            p.write_text(content.replace(old, new), encoding="utf-8")


def prompt_ides() -> list[str]:
    log(f"{BOLD}Which IDE(s) are you using?{RESET} {DIM}(comma-separated for multiple, e.g. 1,2){RESET}")
    log()
    for i, (label, _) in enumerate(IDE_OPTIONS, 1):
        log(f"  {DIM}{i}{RESET}  {label}")
    log(f"  {DIM}{len(IDE_OPTIONS) + 1}{RESET}  All")
    log()

    answer = input(f"Enter number(s) (1–{len(IDE_OPTIONS) + 1}): ").strip()

    try:
        nums = [int(s.strip()) for s in answer.split(",")]
    except ValueError:
        nums = []

    if not nums or any(n < 1 or n > len(IDE_OPTIONS) + 1 for n in nums):
        err(f'Invalid selection "{answer}". Use numbers 1–{len(IDE_OPTIONS) + 1}, comma-separated.')
        sys.exit(1)

    if (len(IDE_OPTIONS) + 1) in nums:
        folders = [folder for _, folder in IDE_OPTIONS]
    else:
        folders = [IDE_OPTIONS[n - 1][1] for n in nums]

    labels = ", ".join(label for label, folder in IDE_OPTIONS if folder in folders)
    log()
    info(f"IDE(s): {BOLD}{labels}{RESET}")
    log()
    return folders


def main():
    target_dir = Path.cwd()
    examples_dir = DATA_DIR / "dpbs-docs" / "vulcan-examples"

    valid_engines = (
        [e for e in ALLOWED_ENGINES if (examples_dir / e).exists()]
        if examples_dir.exists()
        else []
    )

    cli_engine = sys.argv[1].lower() if len(sys.argv) > 1 else None
    if cli_engine and cli_engine not in valid_engines:
        err(f'Unknown engine: "{cli_engine}"')
        log()
        log(f"  Available engines: {', '.join(valid_engines)}")
        log()
        sys.exit(1)

    log()
    log(f"{BOLD}dataproduct-builder-skills{RESET} — scaffolding skills + docs")
    log()

    ide_folders = prompt_ides()

    if cli_engine:
        engine = cli_engine
        info(f"Engine: {BOLD}{engine}{RESET} (from CLI argument)")
    else:
        engine = None
        info(f"Engine: {BOLD}all{RESET} (default)")
    log()

    # ── skills ──
    skills_src = DATA_DIR / "skills"
    installed_skills = []
    if not skills_src.exists():
        warn("skills/ directory not found in package — skipping")
    else:
        skills = [p.name for p in skills_src.iterdir() if p.is_dir()]
        installed_skills = skills
        for ide_folder in ide_folders:
            for skill in skills:
                src = skills_src / skill
                dest = target_dir / ide_folder / "skills" / skill
                existed = dest.exists()
                sync_dir(src, dest)
                rewrite_path_references(dest, "dpbs-docs/dataos", "dpbs-docs/vulcan-docs")
                ok(f"{'updated' if existed else 'created'}  {ide_folder}/skills/{skill}/")

    # ── dpbs-docs (non-examples) ──
    docs_src = DATA_DIR / "dpbs-docs"
    docs_dest = target_dir / "dpbs-docs"

    if not docs_src.exists():
        warn("dpbs-docs/ directory not found in package — skipping")
    else:
        docs_dest.mkdir(parents=True, exist_ok=True)
        for entry in docs_src.iterdir():
            if not entry.is_dir() or entry.name == "vulcan-examples":
                continue
            dest = docs_dest / entry.name
            existed = dest.exists()
            sync_dir(entry, dest)
            n = count_files(entry)
            ok(f"{'updated' if existed else 'created'}  dpbs-docs/{entry.name}/  ({n} file{'' if n == 1 else 's'})")

        loose_src = [p for p in docs_src.iterdir() if p.is_file()]
        loose_names = {p.name for p in loose_src}
        for entry in list(docs_dest.iterdir()):
            if entry.is_file() and entry.name not in loose_names:
                entry.unlink()
        for entry in loose_src:
            dest = docs_dest / entry.name
            existed = dest.exists()
            shutil.copyfile(entry, dest)
            ok(f"{'updated' if existed else 'created'}  dpbs-docs/{entry.name}")

    # ── dpbs-docs/vulcan-examples (filtered or all) ──
    if examples_dir.exists():
        engines_to_copy = [engine] if engine else valid_engines
        for eng in engines_to_copy:
            src = examples_dir / eng
            dest = docs_dest / "vulcan-examples" / eng
            existed = dest.exists()
            sync_dir(src, dest)
            n = count_files(dest)
            ok(f"{'updated' if existed else 'created'}  dpbs-docs/vulcan-examples/{eng}/  ({n} file{'' if n == 1 else 's'})")

    log()
    log(f"{GREEN}{BOLD}Done!{RESET}  Your project now has:")
    log()
    for ide_folder in ide_folders:
        for skill in installed_skills:
            info(f"{ide_folder}/skills/{skill}/")
    info(f"dpbs-docs/vulcan-examples/{engine or '{all engines}'}/")
    info(f"dpbs-docs/vulcan-*.whl  — install: pip install \"dpbs-docs/vulcan-*.whl[{engine or 'ENGINE'}]\"")
    log()
    log("Ask the agent to use the skills — e.g.:")
    log(f'  {CYAN}"design a data product for daily revenue by customer segment"{RESET}')
    log()


if __name__ == "__main__":
    main()

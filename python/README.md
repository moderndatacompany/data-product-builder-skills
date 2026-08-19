# dataproduct-builder-skills (Python)

Python port of the `dataproduct-builder-skills` npm scaffolder — run it via `uvx`/`pipx` instead of `npx`.

```bash
uvx --from . dataproduct-builder-skills snowflake
# or
pipx run --spec . dataproduct-builder-skills snowflake
```

Before building/testing, vendor the shared `skills/` and `dpbs-docs/` content from the repo root:

```bash
python3 scripts/vendor_data.py
```

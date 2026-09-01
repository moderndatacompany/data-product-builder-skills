# Deploying a new version

Both packages (npm `dataproduct-builder-skills` and PyPI `dataproduct-builder-skills`)
ship from this repo and must always carry the **same version** and the same
GitHub tag.

## 0. Working tree must be clean first

`npm version` refuses to run if `git status` shows anything at all — staged or
not. Commit any pending changes (submodule bumps, doc syncs, etc.) as a normal
commit before starting:

```bash
git status
git add -A
git commit -m "..."
```

## 1. Bump npm version

```bash
npm version major   # or: minor | patch
```

This updates `package.json`, commits it, and creates the git tag
(e.g. `v2.0.0`) — but only if the tree was clean per step 0.

## 2. Push the commit + tag to GitHub

```bash
git push origin main --follow-tags
```

## 3. Publish to npm

```bash
npm publish --access public
```

> First time only: `npm login`.

## 4. Bump, build, and publish the Python package

`python/pyproject.toml`'s `version` does **not** auto-sync with
`package.json` — update it manually to match before building:

```bash
cd python
# edit pyproject.toml: version = "2.0.0"
python3 scripts/vendor_data.py
uv build
uv publish
cd ..
```

> First time only: PyPI credentials via `uv publish --token <token>` or `~/.pypirc`.

## 5. Verify

```bash
npm view dataproduct-builder-skills version
pip index versions dataproduct-builder-skills
```

## One-liner (steps 1–3, npm only)

```bash
npm version major && git push origin main --follow-tags && npm publish --access public
```

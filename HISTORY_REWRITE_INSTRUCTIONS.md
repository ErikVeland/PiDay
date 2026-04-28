# Remove `.pnpm-store` from git history (PiDay)

This repo previously had a `.pnpm-store/` directory committed. Even if it was later deleted, the objects remain in git history and can still cause pushes/clones to be huge.

## What I did locally

- Deleted the working-tree `.pnpm-store/` directory.
- Rewrote a mirror clone’s history to **remove `.pnpm-store/` from all commits**.
- Generated a git bundle you can use to replace the remote:
  - `piday-history-clean.bundle`

## Option A (recommended): rewrite + force-push from your machine

> **Warning:** this rewrites history. Anyone with an existing clone must re-clone or hard reset.

1. Install git-filter-repo:
   - macOS (Homebrew): `brew install git-filter-repo`
   - or Python: `python3 -m pip install git-filter-repo`

2. Mirror-clone the repo:
   ```bash
   git clone --mirror https://github.com/ErikVeland/PiDay.git piday-mirror.git
   cd piday-mirror.git
   ```

3. Remove `.pnpm-store` from history:
   ```bash
   git filter-repo --force --path .pnpm-store --invert-paths --no-gc
   git reflog expire --expire=now --all
   git gc --prune=now --aggressive
   ```

4. Force-push rewritten history:
   ```bash
   git push --mirror --force
   ```

## Option B: push the provided bundle

If you want to use the provided `piday-history-clean.bundle`:

1. Create a new mirror repo from the bundle:
   ```bash
   mkdir piday-from-bundle.git
   cd piday-from-bundle.git
   git init --bare
   git fetch /path/to/piday-history-clean.bundle "refs/*:refs/*"
   ```

2. Add the GitHub remote and force-push:
   ```bash
   git remote add origin https://github.com/ErikVeland/PiDay.git
   git push --mirror --force origin
   ```

## After rewriting: fix existing clones

For any existing clone, the safest path is:

```bash
rm -rf PiDay
git clone https://github.com/ErikVeland/PiDay.git
```


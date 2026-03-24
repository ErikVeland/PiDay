# PiDay Website

Marketing and support site for PiDay, built with Next.js and deployed to `https://piday.glasscode.academy`.

## Development

```bash
pnpm install
pnpm dev
```

Open `http://localhost:3000`.

## Quality Checks

```bash
./scripts/quality_gate.sh
```

## Production Deploy

Local deploys and GitHub Actions both use the hardened production SSH identity:

- Host: `194.195.248.217`
- User: `svc_epstein`
- Private key path: `~/.ssh/id_epstein_prod_ed25519`

Run a manual deploy from this directory:

```bash
./deploy.sh
```

Optional flags:

- `--skip-quality`
- `--skip-verify`
- `--dry-run`

## GitHub Actions Secrets

The production workflow expects these repository or environment secrets:

- `PROD_HOST=194.195.248.217`
- `PROD_USER=svc_epstein`
- `PROD_SSH_PRIVATE_KEY=<contents of ~/.ssh/id_epstein_prod_ed25519>`

The workflow normalizes CRLF line endings and also accepts keys pasted with literal `\n` escapes, but the safest option is to paste the raw private key exactly as stored on disk.

## Server Setup

See [SERVER_SETUP.md](/Users/veland/PiDay/website/SERVER_SETUP.md) for nginx, systemd, directory ownership, SSL, and post-deploy verification.

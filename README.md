# buildforge

> A portable bash build script for Docker/Podman projects — auto-versioning, multi-service discovery, self-updating, and extensible via post-build hooks.

---

## Features

- **Auto-versioning** — `static.yyddd.incremental` scheme persisted in `.build`, resets daily
- **Auto-detects registry** — parses `git remote origin` for server, owner, and project name; no hardcoding
- **Two build modes** — single-image (root `Dockerfile`) or multi-service (subdirectory scan), chosen automatically
- **Docker & Podman** — prefers Docker, falls back to Podman; auto-detects `userns` and SELinux flags
- **Self-updating** — `--update` downloads the latest script from your configured URL and replaces itself in-place
- **Post-build hooks** — drop numbered `*.sh` scripts into `buildme.d/` for unlimited extensibility

---

## Installation

Copy `buildme.sh` into your project (or `.devcontainer/`) and make it executable:

```bash
curl -fsSL https://raw.githubusercontent.com/nillth/buildforge/main/buildme.sh -o buildme.sh
chmod +x buildme.sh
```

Then set your update URL at the top of the script:

```bash
UPDATE_URL="https://raw.githubusercontent.com/nillth/buildforge/main/buildme.sh"
```

---

## Usage

```
./buildme.sh [options] [service...]

Options:
  --skip-push            Build images but do not push to registry
  --dry-run              Print all commands without executing them
  --bump-major           Increment the static major version before building
  --engine docker|podman Force a specific container engine
  --extensions           Browse and install hook examples from the repo
  --update               Download and replace this script with the latest version
  --help                 Show help

Arguments:
  service...             Build only these named services (multi-service mode only)
```

### Examples

```bash
# Build and push everything
./buildme.sh

# Build only, no push (e.g. local testing)
./buildme.sh --skip-push

# See exactly what would run without doing anything
./buildme.sh --dry-run

# Build only the backend service
./buildme.sh backend

# Start a new major version
./buildme.sh --bump-major

# Force Podman even if Docker is installed
./buildme.sh --engine podman

# Update this script to the latest version
./buildme.sh --update

# Browse and install hook examples interactively
./buildme.sh --extensions
```

---

## Build Modes

### Single-image

If a `Dockerfile` exists in the **root** of the repo, the script builds one image tagged as:

```
GIT_SERVER/GIT_OWNER/PROJECT_NAME:VERSION
GIT_SERVER/GIT_OWNER/PROJECT_NAME:latest
```

### Multi-service

If there is **no root Dockerfile**, the script scans all subdirectories for a `Dockerfile` and treats each as an independent service:

```
GIT_SERVER/GIT_OWNER/PROJECT_NAME-backend:VERSION
GIT_SERVER/GIT_OWNER/PROJECT_NAME-frontend:VERSION
...
```

Services are discovered automatically — adding a new service just requires creating a subdirectory with a `Dockerfile`.

---

## Versioning

The version format is `STATIC.YYDDD.INCREMENTAL`:

| Part | Description | Example |
|---|---|---|
| `STATIC` | Major version, incremented with `--bump-major` | `1` |
| `YYDDD` | Year + ISO day-of-year | `26097` (day 97 of 2026) |
| `INCREMENTAL` | Resets to `1` each new day, increments each run | `3` |

State is stored in `.build` at the repo root:

```bash
VERSION=1
YYDDD=26097
INCREMENTAL=3
```

---

## Registry Detection

The registry path is parsed from `git remote get-url origin` automatically:

| Remote format | Detected |
|---|---|
| `https://git.example.com/owner/project` | server=`git.example.com` owner=`owner` project=`project` |
| `git@git.example.com:owner/project.git` | same |
| `ssh://git@git.example.com/owner/project` | same |

If no remote is found, the script falls back to `localhost/local/DIRNAME`.

---

## Post-build Hooks

### Installing hooks interactively

Once `UPDATE_URL` is configured, you can browse and install hooks from the repo without leaving your terminal:

```bash
./buildme.sh --extensions
```

```
🔍 Fetching available extensions from Nillth/buildme...

Available extensions:

  [ 1]  azure-containerapp
  [ 2]  slack-notify
  [ 3]  teams-notify
  [ 4]  discord-notify
  [ 5]  ntfy-notify
  ...

Enter numbers to install (space or comma-separated), or all, or q to quit:
> 1 5

⬇️  Downloading 002.azure-containerapp.example.sh...
✅ buildme.d/002.azure-containerapp.example.sh
⬇️  Downloading 020.ntfy-notify.example.sh...
✅ buildme.d/020.ntfy-notify.example.sh

Tip: rename any .example.sh → .sh to activate it.
```

Hooks are downloaded as `.example.sh` (safe, never auto-run). To activate one:

```bash
cp buildme.d/002.azure-containerapp.example.sh buildme.d/002.azure-containerapp.sh
# edit to set your config values
```

### Manual installation

You can also copy any example directly from this repo into your project's `buildme.d/` and rename it.

After build and push, the script sources every `*.sh` file (excluding `*.example.sh`) from a `buildme.d/` directory located next to `buildme.sh`, in lexical order.

```
your-project/
├── buildme.sh
└── buildme.d/
    ├── 001.azure-containerapp.sh    ← runs first
    ├── 002.slack-notify.sh          ← runs second
    └── 003.healthcheck-poll.sh      ← runs third
```

### Hook environment

Every hook is `source`d, so it has full access to:

| Variable | Description |
|---|---|
| `NEW_VERSION` | The version just built, e.g. `1.26097.3` |
| `BUILT_REPOS` | Array of image repo paths |
| `ENGINE` | `docker` or `podman` |
| `SKIP_PUSH` | `true` if `--skip-push` was passed |
| `DRY_RUN` | `true` if `--dry-run` was passed |
| `GIT_SERVER` | Registry host |
| `GIT_OWNER` | Registry owner/namespace |
| `PROJECT_NAME` | Project name |
| `GIT_ROOT` | Absolute path to the repo root |
| `run_cmd` | Wrapper that respects `--dry-run` |

> **Important:** Use `return 0` (not `exit 0`) to bail out of a hook early — hooks are sourced, so `exit` would terminate the parent shell.

### Naming convention

| Filename | Behaviour |
|---|---|
| `001.my-hook.sh` | Active — runs automatically |
| `001.my-hook.example.sh` | Template — ignored, never runs |

To activate a template: copy it and drop the `.example` suffix.

---

## Hook Library

Ready-made example hooks are included in `buildme.d/`. Copy and rename to activate.

### Notifications
| Hook | Description |
|---|---|
| `003.slack-notify.example.sh` | Slack Incoming Webhook |
| `004.teams-notify.example.sh` | Microsoft Teams Webhook card |
| `005.discord-notify.example.sh` | Discord Webhook embed |
| `020.ntfy-notify.example.sh` | ntfy push notification (self-hosted or ntfy.sh) |

### Deployments
| Hook | Description |
|---|---|
| `002.azure-containerapp.example.sh` | Azure Container App update via `az cli` |
| `008.ssh-remote-redeploy.example.sh` | SSH → `docker compose pull && up -d` |
| `009.kubectl-rollout.example.sh` | Kubernetes `kubectl set image` + rollout wait |
| `010.portainer-webhook.example.sh` | Portainer stack webhook |
| `011.watchtower-trigger.example.sh` | Watchtower HTTP API trigger |
| `024.flyio-deploy.example.sh` | Fly.io deploy via `flyctl` |
| `025.coolify-webhook.example.sh` | Coolify deployment webhook |

### Security
| Hook | Description |
|---|---|
| `016.trivy-scan.example.sh` | Trivy vulnerability scan — blocks on HIGH/CRITICAL |
| `017.cosign-sign.example.sh` | Sigstore cosign image signing (keyless or key-based) |

### Registry
| Hook | Description |
|---|---|
| `018.mirror-registry.example.sh` | Re-tag and push to a secondary registry |
| `015.prune-old-images.example.sh` | Remove old local image tags, keep last N |

### Kubernetes / Helm
| Hook | Description |
|---|---|
| `009.kubectl-rollout.example.sh` | Rollout new image to a deployment |
| `022.helm-values-update.example.sh` | Update `values.yaml` tags, optionally run `helm upgrade` |

### Version file sync
| Hook | Description |
|---|---|
| `007.update-compose-image.example.sh` | Pin new tag in `docker-compose.yml` |
| `012.sync-version-package-json.example.sh` | Write version into `package.json` |
| `013.sync-version-cargo-toml.example.sh` | Write version into `Cargo.toml` |

### Source control & release
| Hook | Description |
|---|---|
| `006.git-tag-release.example.sh` | Create and push a `vX.Y.Z` git tag |
| `019.gitea-github-release.example.sh` | Create a Gitea/GitHub release with commit notes |
| `023.trigger-pipeline.example.sh` | Fire a `repository_dispatch` event |
| `026.changelog-append.example.sh` | Prepend a `CHANGELOG.md` entry from git log |

### Quality & testing
| Hook | Description |
|---|---|
| `014.healthcheck-poll.example.sh` | Poll a URL until HTTP 200 or timeout |
| `021.smoke-test.example.sh` | Run the image briefly to catch runtime packaging failures |

---

## Requirements

- `bash` 4.0+
- `docker` or `podman`
- `git` (for remote detection, tagging hooks)
- `curl` or `wget` (for `--update` and webhook hooks)

---

## Contributing

1. Fork `buildforge`
2. Add your hook to `buildme.d/` as `NNN.description.example.sh`
3. Open a pull request

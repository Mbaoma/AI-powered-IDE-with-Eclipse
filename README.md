# AI-powered-IDE-with-Eclipse

A customizable, secure, and scalable development workspaces using Eclipse Theia and Google Cloud

## Layout

```markdown
config/                 Single source of truth for IDE configuration
  theia.app.json        Branding, default preferences, bundled VS Code extensions
  .env.example          Template for Phase 3 AI credentials (not used yet)
ide/                    The scaffolded Theia browser application
scripts/
  setup.sh              Install deps, sync config, build, download plugins
  start.sh              Launch the IDE against workspace/
  smoke-test.sh         Headless boot + health check (see "Testing" below)
  sync-theia-config.js  Merges config/theia.app.json into ide/package.json
workspace/              Sample project opened by the IDE (one file per language)
```

## Phase 4: Security Assessment

Phase 4 covers IAM, private extension management, workspace policies as code, automated image rebuilds/scanning, and audit logging. Before building that out, this is a baseline security assessment of everything Phases 1-3 already shipped.

**Result: zero high-confidence (≥8/10) vulnerabilities.** No injection, auth bypass, hardcoded real credentials, or data exposure was found in project-authored code -- this project has no custom backend accepting untrusted network input, only Theia configuration, a Dockerfile, and local `gcloud`/bash deployment scripts the developer runs against their own infrastructure.

The review did surface five lower-confidence items (1-2/10) -- correctly excluded as not concretely exploitable in this project's actual single-developer threat model, but still legitimate hardening opportunities worth working through deliberately rather than leaving on the table:

| # | Issue | File | Severity if unaddressed | Status |
|---|---|---|---|---|
| 1 | `GOOGLE_API_KEY` passed as a plaintext `gcloud --container-env` CLI argument and stored as a plaintext field on the Workstations config resource, instead of via Secret Manager | `scripts/gcp-create-workstation.sh` | Low (matters more once other GCP principals share the project) | **Fixed** (see Remediations) |
| 2 | NodeSource install script run via `curl \| bash` as root during image build, with no checksum/signature pinning | `config/docker/Dockerfile` | Low (supply-chain trust in NodeSource + TLS channel) | **Fixed** (see Remediations) |
| 3 | Runtime container has no `USER` directive -- Theia and everything it runs (extensions, debug adapters, developer code) executes as root | `config/docker/Dockerfile` | Low (bounded by the fact that arbitrary code execution is this IDE's actual purpose) | **Fixed, needs your verification** (see Remediations) |
| 4 | Smoke-test scripts write to predictable `/tmp` paths instead of `mktemp`, unlike `smoke-test.sh`'s own server log | `scripts/smoke-test.sh`, `scripts/docker-smoke-test.sh` | Low (local-only, bounded to a bogus test verdict) | **Fixed** (see Remediations) |

**Exit criteria:** each item above is either fixed or explicitly accepted as out of scope, and the broader Phase 4 proposal items (IAM role hierarchy, private Open VSX registry with an approved extension allowlist, policy-as-code for workstation/network/IAM config, scheduled image rebuild + Artifact Registry vulnerability scanning, Cloud Audit Log sinks with alerting) are scoped into follow-up work.

## Remediations

### 1. `GOOGLE_API_KEY` no longer passed as a plaintext `gcloud` argument

Cloud Workstations has no native secret-reference flag for `--container-env` (unlike Cloud Run's `--set-secrets`), so the fix moves the value into Secret Manager and has the **workstation itself fetch it at startup**, using its own attached service account -- rather than the deploy script injecting it.

### 2. NodeSource installed via apt and a pinned keyring, not `curl | bash`

Replaced the installer-script pattern with [NodeSource's own officially documented manual method](https://github.com/nodesource/distributions/wiki/Repository-Manual-Installation): download their GPG public key, add it to a dedicated keyring, and register their apt repo pointed at that keyring -- then let `apt-get` do the actual package install and verification, the same trust model every other apt package in the image already uses.

The only thing fetched and executed outside `apt`'s own signature checking is now a GPG **public key** (inert data, not executable code), instead of an arbitrary root shell script. A compromised `deb.nodesource.com` could still serve a malicious key at first fetch (true of any HTTPS-only trust-on-first-use, including the previous approach), but it can no longer run arbitrary commands directly -- it would have to additionally forge a signed `.deb` package, a meaningfully smaller attack surface.

```dockerfile
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
printf 'Types: deb\nURIs: https://deb.nodesource.com/node_22.x/\nSuites: nodistro\nComponents: main\nSigned-By: /etc/apt/keyrings/nodesource.gpg\n' > /etc/apt/sources.list.d/nodesource.sources
apt-get update && apt-get install -y --no-install-recommends nodejs
```

### 3. Theia runs as a non-root user
- `config/docker/Dockerfile` creates a non-root `theia` user (fixed UID 1000) and `chown`s `/opt/theia` and `/opt/sample-workspace` (both outside `/home`, so this persists) to it. No `USER` directive.
- `config/docker/entrypoint.sh` still starts as root (the container's default, since nothing changed that), seeds the workspace as before, then -- **after** the persistent disk is actually mounted -- creates `/home/theia`, `chown -R`s all of `/home` to `theia:theia`, sets `HOME=/home/theia` (so Theia's own config/plugin-cache directory, which Theia derives from `$HOME`, lands somewhere the non-root user can actually write), and finally execs `theia start` via `setpriv --reuid=theia --regid=theia --init-groups` -- a clean privilege drop that directly replaces the entrypoint process (no wrapper shell, so signal handling for graceful container stop still works correctly), rather than `su`/`sudo`, which wrap the command in an extra process.

### 4. Smoke-test scripts now use `mktemp` instead of predictable `/tmp` paths

`scripts/smoke-test.sh` and `scripts/docker-smoke-test.sh` both wrote their fetched root-page HTML to fixed filenames (`/tmp/theia-smoke-root.html`, `/tmp/ai-ide-docker-smoke-root.html`) -- unlike `smoke-test.sh`'s own server log, which already used `mktemp`. Both now generate the path with `mktemp` the same way, and both clean the file up in their existing `trap cleanup EXIT` handler (which neither did before, for these files -- a small leftover-file-sprawl fix alongside the main one).

## Documentation

- [Eclipse Theia docs](https://theia-ide.org/docs/): user and adopter documentation for the Theia platform this IDE is built on
- [Eclipse Theia GitHub](https://github.com/eclipse-theia/theia): source, extension API, and issue tracker
- [Theia CLI (`@theia/cli`) README](https://github.com/eclipse-theia/theia/blob/master/dev-packages/cli/README.md): `theia build` / `theia start` / `theia download:plugins`, used throughout `scripts/`
- [Authoring VS Code Extensions for Theia](https://theia-ide.org/docs/authoring_vscode_extensions/): how the bundled extensions in `config/theia.app.json` get built and published
- [Open VSX Registry](https://open-vsx.org): the bundled extensions
- [Eclipse Foundation](https://www.eclipse.org/): project governance and the Eclipse ecosystem
- [Using AI Features in Theia IDE](https://theia-ide.org/docs/user_ai/): how Theia AI's provider/agent settings work, including the built-in Google AI provider Phase 3 uses
- [Gemini API docs](https://ai.google.dev/gemini-api/docs): the Developer API Phase 3 calls
- [Gemini API pricing / free tier](https://ai.google.dev/gemini-api/docs/pricing): current free-tier model list and limits
- [Google AI Studio](https://aistudio.google.com/apikey): where to generate the free `GOOGLE_API_KEY`

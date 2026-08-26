# Webcore Panel Bootstrap

Public bootstrap installer for a new Webcore Panel server.

The Webcore application source remains in the private `craggyh/webcore-wordpress-platform` repository. This repository contains only the minimal bootstrap needed to establish per-server read-only repository access and hand off to the private production installer.

## Supported systems

- Ubuntu 24.04 LTS
- Ubuntu 26.04 LTS

## Fresh install

Run from an interactive root-capable shell:

```bash
curl -fsSL https://raw.githubusercontent.com/craggyh/Webcore-Panel/main/install.sh | sudo bash
```

The bootstrap will:

1. Verify the supported Ubuntu release.
2. Install the small set of bootstrap prerequisites.
3. Generate or reuse `/etc/webcore/github-deploy-key`.
4. Display the public key if repository access has not yet been configured.
5. Ask you to add that key to `craggyh/webcore-wordpress-platform` as a **read-only** GitHub deploy key.
6. Verify access to the private `main` branch.
7. Clone the private production source into a temporary bootstrap workspace.
8. Run the private `installer/install.sh` production installer.
9. Leave future upgrades to the Webcore Panel Administration → Updates workflow.

The deploy key is unique to the server. Do not enable **Allow write access** when adding it to GitHub.

## Re-running

The bootstrap is intentionally resumable. If `/etc/webcore/github-deploy-key` already exists it is reused, so an interrupted installation does not create another deploy key.

## Repository boundaries

This public repository must never contain application source, production secrets, private repository credentials, licensing secrets, or server-specific private keys.

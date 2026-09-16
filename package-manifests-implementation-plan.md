# Implementation Plan: Separate Package Manifests from Installation Logic

## Purpose

Refactor the existing `linux-setup` repository so that simple package names are stored in package manifest files instead of being hardcoded throughout Bash modules.

The goal is to make the repository easier to maintain, easier to review, and safer to extend without changing installation logic every time a package is added or removed.

This plan is intended to be handed directly to Codex and implemented locally in the existing repository.

---

## Current Repository Context

The repository currently follows a modular structure similar to:

```text
linux-setup/
├── install.sh
├── settings.sh
├── README.md
├── .gitignore
├── lib/
│   └── common.sh
├── configs/
│   ├── zsh/
│   │   └── .zshrc
│   └── espanso/
│       └── match/
│           └── base.yml
└── modules/
    ├── 00-system.sh
    ├── 10-shell.sh
    ├── 20-terminal.sh
    ├── 30-dev.sh
    ├── 40-apps.sh
    ├── 50-tools.sh
    ├── 60-virtualization.sh
    ├── 70-legion.sh
    └── 90-services.sh
```

Supported Linux families:

- Debian / Ubuntu
- Fedora
- Arch / CachyOS / Omarchy

The project should remain:

- Bash-based
- modular
- idempotent
- safe to rerun
- profile-free
- easy to understand without requiring Ansible or another configuration-management framework

---

## 1. Goals

Implement package manifests for simple repository packages.

After the refactor:

- package names should not be scattered throughout unrelated Bash logic;
- package installation logic should live in reusable helper functions;
- distro-specific package naming differences should be represented in manifest files;
- complex software should continue using dedicated modules;
- comments and blank lines should be allowed inside manifest files;
- rerunning the setup must remain safe;
- unsupported packages should produce useful warnings rather than breaking the whole setup unnecessarily.

---

## 2. Non-Goals

Do not move complex application installers into package manifests.

The following should remain dedicated installation logic because they need repositories, services, configuration, downloads, source builds, or other special handling:

- Docker
- Brave
- VS Code
- NVM / Node.js
- WezTerm
- Oh My Zsh
- Espanso
- Postman
- LenovoLegionLinux
- Syncthing service configuration
- rclone configuration
- KVM / libvirt networking configuration
- Input Remapper service/configuration
- Steam/Lutris Flatpak logic if currently installed through Flatpak

Do not add profiles such as:

```text
minimal
dev
gaming
full
```

The user explicitly does not want profiles.

---

## 3. Target Repository Structure

Add a new `packages/` directory.

Target:

```text
linux-setup/
├── install.sh
├── settings.sh
├── README.md
├── .gitignore
│
├── lib/
│   ├── common.sh
│   └── packages.sh
│
├── packages/
│   ├── common.txt
│   ├── debian.txt
│   ├── fedora.txt
│   ├── arch.txt
│   ├── development-common.txt
│   ├── development-debian.txt
│   ├── development-fedora.txt
│   ├── development-arch.txt
│   ├── utilities-common.txt
│   ├── utilities-debian.txt
│   ├── utilities-fedora.txt
│   └── utilities-arch.txt
│
├── configs/
│   ├── zsh/
│   │   └── .zshrc
│   └── espanso/
│       └── match/
│           └── base.yml
│
└── modules/
    ├── 00-system.sh
    ├── 10-shell.sh
    ├── 20-terminal.sh
    ├── 30-dev.sh
    ├── 40-apps.sh
    ├── 50-tools.sh
    ├── 60-virtualization.sh
    ├── 70-legion.sh
    └── 90-services.sh
```

If fewer manifest files are sufficient after inspecting the real repository, keep the design simpler.

Preferred rule:

- create a common manifest when package names are shared;
- create distro-specific manifests only when names differ or a package exists only on one distro.

Avoid unnecessary duplication.

---

## 4. Manifest File Format

Manifest files are plain text.

Example:

```text
# Common command-line tools

git
curl
wget
jq
tree
rsync
ripgrep
tmux
htop
btop
```

Rules:

1. One package per line.
2. Blank lines are ignored.
3. Lines beginning with `#` are comments.
4. Leading and trailing whitespace should be ignored.
5. Inline comments are not required.
6. Duplicate package names should not cause duplicate installation attempts.
7. Package ordering should remain deterministic.

Do not use YAML, JSON, TOML, or shell arrays for the package manifests.

Plain text is intentionally preferred.

---

## 5. Package Categories

The exact package list must be derived from the existing repository.

Do not invent large new package sets during this refactor.

Move only packages that already exist in the project unless a package is strictly required to support the new implementation.

Suggested grouping:

### `packages/common.txt`

Packages that:

- are needed by most modules; and
- use the same package name on all supported distro families.

Possible examples, only if already installed by the current project:

```text
git
curl
wget
jq
tree
rsync
ripgrep
tmux
htop
btop
```

### `packages/debian.txt`

Base packages whose Debian/Ubuntu names differ.

Possible examples:

```text
ca-certificates
gnupg
openssh-client
openssh-server
fd-find
```

### `packages/fedora.txt`

Fedora equivalents.

Possible examples:

```text
ca-certificates
gnupg2
openssh-clients
openssh-server
fd-find
```

### `packages/arch.txt`

Arch/CachyOS/Omarchy equivalents.

Possible examples:

```text
ca-certificates
gnupg
openssh
fd
```

### Development manifests

Use development manifests for ordinary compiler/runtime support packages that do not need custom configuration.

Examples may include:

Debian:

```text
build-essential
pkg-config
cmake
python3
python3-pip
python3-venv
pipx
```

Fedora:

```text
gcc
gcc-c++
make
cmake
pkgconf-pkg-config
python3
python3-pip
pipx
```

Arch:

```text
base-devel
cmake
pkgconf
python
python-pip
python-pipx
```

Use actual available package names after checking the current scripts.

---

## 6. New Package Helper Library

Create:

```text
lib/packages.sh
```

This file should contain reusable package-manifest functions.

It may source `lib/common.sh`, or `install.sh` may source both.

Implement the following responsibilities.

### 6.1 `package_manifest_path`

Optional helper.

Purpose:

Resolve a manifest name relative to repository root.

Example interface:

```bash
package_manifest_path "packages/common.txt"
```

Return or print the absolute path.

If the project already exposes something like `REPO_ROOT`, reuse it.

Do not depend on the user's current working directory.

### 6.2 `read_package_manifest`

Purpose:

Read a manifest and produce normalized package names.

Requirements:

- ignore blank lines;
- ignore comment lines;
- trim surrounding whitespace;
- remove duplicates;
- preserve first-seen ordering;
- fail clearly if a required manifest does not exist.

Suggested usage:

```bash
mapfile -t packages < <(read_package_manifest "$manifest")
```

Do not execute manifest contents as shell code.

### 6.3 `install_package_manifest`

Main helper.

Suggested interface:

```bash
install_package_manifest "packages/common.txt"
```

Behavior:

1. resolve path;
2. parse file;
3. return successfully if the manifest has no packages;
4. install the packages using the package manager for the detected distro family;
5. use non-interactive flags where the current repository already does so;
6. avoid reinstalling packages where possible;
7. log which manifest is being processed.

Prefer installing a manifest's packages in a single package-manager transaction instead of one process per package.

Examples:

Debian:

```bash
sudo apt-get install -y "${packages[@]}"
```

Fedora:

```bash
sudo dnf install -y "${packages[@]}"
```

Arch:

```bash
sudo pacman -S --needed --noconfirm "${packages[@]}"
```

However, respect the current repository's package-manager implementation if it already provides good abstractions.

---

## 7. Package Availability Behavior

The current setup should not become fragile simply because one optional package is unavailable.

Implement one of these approaches:

### Preferred

Validate availability before installation and split packages into:

- available
- unavailable

Log warnings for unavailable packages.

Install only available packages.

Example:

```text
[WARN] Package not available on Fedora: example-package
```

### Acceptable alternative

If the existing project already has an `install_pkg` helper that safely checks availability, reuse it.

In that case, `install_package_manifest` may iterate through normalized package names using that helper.

Batch installation is preferred, but reliability is more important than optimization.

Do not silently ignore missing packages.

---

## 8. Distro Family Naming

Use one consistent family variable everywhere.

Preferred values:

```text
debian
fedora
arch
```

Examples:

- Ubuntu -> `debian`
- Debian -> `debian`
- Fedora -> `fedora`
- Arch -> `arch`
- CachyOS -> `arch`
- Omarchy -> `arch`

Do not create separate manifests for CachyOS and Omarchy unless there is a real package-name difference.

Reuse existing distro detection where possible.

Do not introduce a second conflicting distro-detection system.

---

## 9. Refactor `modules/00-system.sh`

Move ordinary base packages out of this module.

Before refactor, it may contain logic like:

```bash
case "$FAMILY" in
    debian)
        install_many git curl wget ...
        ;;
    fedora)
        install_many git curl wget ...
        ;;
    arch)
        install_many git curl wget ...
        ;;
esac
```

Replace simple package lists with manifest installation.

Target concept:

```bash
install_package_manifest "packages/common.txt"
install_package_manifest "packages/${FAMILY}.txt"
install_package_manifest "packages/utilities-common.txt"

if [[ -f "$REPO_ROOT/packages/utilities-${FAMILY}.txt" ]]; then
    install_package_manifest "packages/utilities-${FAMILY}.txt"
fi
```

Keep system-update logic in `00-system.sh`.

Examples of logic that should stay in the module:

- `apt-get update`
- `dnf upgrade --refresh`
- `pacman -Syu`
- repository refresh
- distro detection
- system-level preparation

---

## 10. Refactor `modules/30-dev.sh`

Move simple development packages into development manifests.

Keep custom installers and configuration in `30-dev.sh`.

The module should continue to handle things such as:

- Docker official repository setup
- Docker service enabling
- Docker group membership
- Docker verification
- VS Code repository/AUR setup
- NVM installation
- Node LTS installation
- shell integration for NVM

The module should stop containing long distro-specific arrays for simple packages such as:

- compilers
- Python
- pip
- venv
- pipx
- cmake
- pkg-config equivalents

Target concept:

```bash
install_package_manifest "packages/development-common.txt"

if [[ -f "$REPO_ROOT/packages/development-${FAMILY}.txt" ]]; then
    install_package_manifest "packages/development-${FAMILY}.txt"
fi
```

---

## 11. Refactor Other Modules Carefully

Inspect every module for hardcoded package lists.

Candidates:

```text
10-shell.sh
20-terminal.sh
40-apps.sh
50-tools.sh
60-virtualization.sh
70-legion.sh
90-services.sh
```

Move only ordinary package dependencies.

Do not move package names if they are tightly coupled to special logic and separating them would make the module harder to understand.

Example:

A virtualization module may require several distro-specific packages before configuring libvirt.

It is acceptable to create:

```text
packages/virtualization-debian.txt
packages/virtualization-fedora.txt
packages/virtualization-arch.txt
```

if that improves clarity.

Likewise, LenovoLegionLinux build dependencies may justify:

```text
packages/legion-debian.txt
packages/legion-fedora.txt
packages/legion-arch.txt
```

Do not force every package into only the top-level three manifests.

Use domain-specific manifests when they make ownership clearer.

---

## 12. Manifest Naming Convention

Use:

```text
<domain>-common.txt
<domain>-debian.txt
<domain>-fedora.txt
<domain>-arch.txt
```

Examples:

```text
utilities-common.txt
development-common.txt
development-debian.txt
development-fedora.txt
development-arch.txt
virtualization-debian.txt
virtualization-fedora.txt
virtualization-arch.txt
```

If there is no common list for a domain, omit it.

Avoid empty manifest files unless they provide meaningful documentation.

---

## 13. Preserve Idempotence

The refactor must not make reruns destructive.

Required behavior:

- `apt`, `dnf`, and `pacman` should tolerate already-installed packages;
- no manifest should directly modify config files;
- package manifests must not contain shell commands;
- repository setup must not be repeated unnecessarily;
- services must continue to use safe `enable --now` behavior;
- Docker group membership should remain safe on rerun;
- config backups should not be created unnecessarily just because package manifests changed.

---

## 14. Logging

Every manifest installation should produce clear output.

Example:

```text
==> Installing package manifest: packages/common.txt
    git curl wget jq tree rsync

==> Installing package manifest: packages/development-fedora.txt
    gcc gcc-c++ make cmake python3 python3-pip
```

Warnings:

```text
[WARN] Skipping unavailable package: example
```

Errors:

```text
[ERROR] Required package manifest does not exist:
        /path/to/linux-setup/packages/common.txt
```

Use the repository's existing `log`, `ok`, `warn`, and `die` helpers if available.

Do not create a second logging style.

---

## 15. Comments Inside Manifest Files

Use comments to explain non-obvious choices.

Good:

```text
# Arch package name differs from Debian/Fedora.
fd
```

Good:

```text
# Required to build AUR packages such as brave-bin.
base-devel
```

Avoid obvious comments such as:

```text
# Install git
git
```

---

## 16. Package Manager Functions

If `lib/common.sh` currently owns package-management functions, decide between:

### Option A — Preferred

Keep low-level package-manager operations in:

```text
lib/common.sh
```

and put only manifest parsing/orchestration in:

```text
lib/packages.sh
```

Example:

```text
common.sh
  pkg_installed
  pkg_available
  install_pkg
  install_many

packages.sh
  read_package_manifest
  install_package_manifest
```

### Option B

Move all package-specific helpers into `lib/packages.sh`.

Only do this if it makes the current structure clearer.

Do not duplicate helpers between the two files.

---

## 17. Shell Safety Requirements

All scripts should continue using strict mode where appropriate:

```bash
set -Eeuo pipefail
```

Quote paths and expansions.

Use arrays for package names.

Good:

```bash
sudo apt-get install -y "${packages[@]}"
```

Bad:

```bash
sudo apt-get install -y $packages
```

Manifest paths must handle spaces safely even though the repository normally will not contain them.

Never use:

```bash
eval
```

for package manifest parsing.

---

## 18. Testing

Add lightweight tests.

Create:

```text
tests/
├── test-manifests.sh
└── test-syntax.sh
```

### 18.1 `tests/test-syntax.sh`

Run Bash syntax validation against all shell scripts.

Example:

```bash
find . -type f -name '*.sh' -print0 |
while IFS= read -r -d '' file; do
    bash -n "$file"
done
```

Return non-zero on failure.

### 18.2 `tests/test-manifests.sh`

Validate every manifest.

Checks:

- file is readable;
- no accidental shell syntax;
- no lines beginning with package-manager commands;
- no duplicate normalized package names within the same manifest;
- no trailing whitespace if practical;
- comments and blanks parse correctly.

Example failures:

```text
Duplicate package in packages/common.txt: git
Invalid manifest line in packages/common.txt:
sudo apt install vim
```

A manifest entry should be a package name, not a command.

Allow package names containing typical package characters:

```text
A-Z
a-z
0-9
+
-
.
_
@
:
```

Do not over-restrict legitimate distro package naming.

---

## 19. ShellCheck

If ShellCheck is already installed by the project or available in CI, run it against all shell files.

Do not require ShellCheck as a mandatory runtime dependency of the setup itself.

Optional development command:

```bash
shellcheck install.sh lib/*.sh modules/*.sh tests/*.sh
```

Fix meaningful warnings introduced by this refactor.

Do not blindly disable warnings globally.

---

## 20. README Changes

Update `README.md`.

Add a section:

```markdown
## Package manifests
```

Explain:

- simple packages live in `packages/`;
- complex software remains under `modules/`;
- how common and distro-specific manifests work;
- how to add a new package;
- how to handle different package names between distro families.

Example documentation:

```markdown
To add `fastfetch` everywhere, add it to an appropriate common
manifest if the package name is identical on all supported distros.

If the package names differ, add each distro-specific name to the
corresponding manifest.
```

Also document:

```bash
./tests/test-syntax.sh
./tests/test-manifests.sh
```

---

## 21. Do Not Expose Secrets

Do not alter the user's Espanso snippets or move secrets into package manifests.

The existing Espanso config may contain personal addresses or other private text.

Package manifests must contain package names only.

This refactor must not commit:

- passwords;
- API keys;
- rclone credentials;
- SSH private keys;
- access tokens;
- Docker credentials;
- GitHub tokens.

---

## 22. Migration Procedure

Perform the refactor incrementally.

### Phase 1 — Inventory

Inspect every `modules/*.sh` file.

Create a table or working list containing:

```text
package name
current module
distro family
simple package or complex installer
target manifest
```

Do not edit until the inventory is complete.

### Phase 2 — Add package infrastructure

Create:

```text
lib/packages.sh
packages/
```

Implement and test:

```bash
read_package_manifest
install_package_manifest
```

Do not remove existing package arrays yet.

### Phase 3 — Migrate base packages

Move packages from:

```text
modules/00-system.sh
```

into manifests.

Run syntax and manifest tests.

Run a dry inspection of the script changes.

### Phase 4 — Migrate development dependencies

Refactor:

```text
modules/30-dev.sh
```

Move only simple packages.

Keep Docker, NVM, VS Code, and custom repository setup in Bash.

Run tests.

### Phase 5 — Migrate remaining modules

Review modules one at a time.

Possible order:

```text
10-shell.sh
20-terminal.sh
40-apps.sh
50-tools.sh
60-virtualization.sh
70-legion.sh
90-services.sh
```

Do not create manifests merely for the sake of creating manifests.

If a module contains only two packages that are inseparable from its logic, leaving them inline may be clearer.

### Phase 6 — Remove obsolete helpers

After every call site has been migrated, identify helpers that are no longer used.

Remove only genuinely unused code.

Examples may include old large distro-specific arrays.

Do not remove generic helpers such as:

```bash
install_pkg
pkg_available
pkg_installed
```

if they are still useful.

### Phase 7 — Documentation and validation

Update README.

Run:

```bash
bash -n install.sh
bash -n lib/*.sh
bash -n modules/*.sh
bash -n tests/*.sh

./tests/test-syntax.sh
./tests/test-manifests.sh
```

If ShellCheck is available:

```bash
shellcheck install.sh lib/*.sh modules/*.sh tests/*.sh
```

---

## 23. Acceptance Criteria

The implementation is complete when all of the following are true.

### Repository organization

- [ ] `packages/` exists.
- [ ] simple package lists are stored in manifests.
- [ ] complex installers remain in modules.
- [ ] distro-specific naming differences are clear.

### Code

- [ ] manifest parsing is implemented once.
- [ ] blank lines work.
- [ ] comments work.
- [ ] duplicate handling works.
- [ ] paths do not depend on current working directory.
- [ ] package names are handled using arrays.
- [ ] no `eval` is used.

### Supported systems

- [ ] Ubuntu/Debian path works.
- [ ] Fedora path works.
- [ ] Arch path works.
- [ ] CachyOS maps to Arch.
- [ ] Omarchy maps to Arch.

### Existing functionality

- [ ] WezTerm installation still works.
- [ ] WezTerm config repo still works.
- [ ] Zsh and Oh My Zsh still work.
- [ ] `zsh-autosuggestions` still works.
- [ ] `zsh-completions` still works.
- [ ] NVM still loads in Zsh.
- [ ] Node LTS still installs.
- [ ] Python tooling still installs.
- [ ] Docker still installs/configures.
- [ ] VS Code still installs.
- [ ] Brave still installs.
- [ ] Telegram still installs.
- [ ] Steam still installs.
- [ ] Lutris still installs.
- [ ] Postman still installs.
- [ ] Espanso still installs/configures.
- [ ] Syncthing still installs/configures.
- [ ] rclone still installs.
- [ ] Solaar still installs.
- [ ] Input Remapper still installs.
- [ ] KVM/libvirt still installs/configures.
- [ ] default libvirt NAT network still works.
- [ ] LenovoLegionLinux detection/install still works.

### Quality

- [ ] all Bash files pass `bash -n`.
- [ ] manifest test passes.
- [ ] ShellCheck has no new important warnings if available.
- [ ] rerunning the installer is safe.
- [ ] README explains package manifests.

---

## 24. Example Final Module

A system module should become closer to:

```bash
#!/usr/bin/env bash

log "Installing base packages"

install_package_manifest "packages/common.txt"
install_package_manifest "packages/${FAMILY}.txt"

if [[ -f "$REPO_ROOT/packages/utilities-common.txt" ]]; then
    install_package_manifest "packages/utilities-common.txt"
fi

if [[ -f "$REPO_ROOT/packages/utilities-${FAMILY}.txt" ]]; then
    install_package_manifest "packages/utilities-${FAMILY}.txt"
fi
```

Instead of:

```bash
case "$FAMILY" in
    debian)
        install_many             git curl wget vim neovim             python3 python3-pip ...
        ;;
    fedora)
        install_many             git curl wget vim-enhanced neovim             python3 python3-pip ...
        ;;
    arch)
        install_many             git curl wget vim neovim             python python-pip ...
        ;;
esac
```

The second style mixes package data and installation logic.

The first style keeps them separate.

---

## 25. Example Final Package Helper

Illustrative only; adapt to the existing helper architecture.

```bash
read_package_manifest() {
    local manifest="$1"

    [[ -f "$manifest" ]] || die "Package manifest not found: $manifest"

    awk '
        {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
        }

        $0 == "" {
            next
        }

        /^#/ {
            next
        }

        !seen[$0]++ {
            print $0
        }
    ' "$manifest"
}

install_package_manifest() {
    local relative_path="$1"
    local manifest="$REPO_ROOT/$relative_path"
    local -a packages=()

    mapfile -t packages < <(read_package_manifest "$manifest")

    if (( ${#packages[@]} == 0 )); then
        warn "No packages found in $relative_path"
        return 0
    fi

    log "Installing package manifest: $relative_path"

    case "$FAMILY" in
        debian)
            sudo apt-get install -y "${packages[@]}"
            ;;

        fedora)
            sudo dnf install -y "${packages[@]}"
            ;;

        arch)
            sudo pacman -S --needed --noconfirm "${packages[@]}"
            ;;

        *)
            die "Unsupported package family: $FAMILY"
            ;;
    esac
}
```

Do not copy this blindly if the current repository already has better availability checking or package-manager wrappers.

Integrate with the existing architecture.

---

## 26. Recommended Commit Strategy

Use small commits if this work is done in Git.

Suggested sequence:

```text
refactor: add package manifest infrastructure

refactor: move base packages to manifests

refactor: move development packages to manifests

refactor: migrate remaining simple package dependencies

test: validate package manifests

docs: document package manifest workflow
```

This makes regressions easier to isolate.

---

## 27. Instructions to Codex

When implementing this plan:

1. Inspect the repository before changing anything.
2. Reuse existing helpers where reasonable.
3. Do not rewrite working modules unnecessarily.
4. Keep behavior identical unless this plan explicitly changes it.
5. Do not add profiles.
6. Do not replace Bash with another provisioning system.
7. Do not expose secrets.
8. Do not simplify away distro-specific behavior that is currently required.
9. Prefer small focused edits.
10. Run tests after each migration phase.
11. If a current package name differs from examples in this plan, trust the actual existing repository and current distro packaging rather than the example.
12. At the end, provide a concise summary of:
    - files added;
    - files changed;
    - packages moved;
    - logic intentionally left in modules;
    - test results;
    - any unresolved distro-specific issue.

---

## 28. Expected Result

After this refactor, adding a normal package should usually require editing a text file rather than Bash.

Example:

Before:

```bash
install_many git curl wget fastfetch jq tree
```

After:

```text
# packages/utilities-common.txt

git
curl
wget
fastfetch
jq
tree
```

The Bash installer remains responsible for:

```text
How do I install packages on this distro?
```

The manifests answer:

```text
Which packages should this setup install?
```

That separation is the entire purpose of this refactor.

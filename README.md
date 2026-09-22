# Personal Linux Setup

A reusable fresh-PC installer for the Linux systems I use:

- Ubuntu / Debian
- Fedora
- Arch Linux / CachyOS / Omarchy

There are no profiles. `./install.sh` installs the setup selected in `settings.sh`.

## Main stack

### Terminal and shell
- WezTerm
- WezTerm config from `mont2y/wezterm-config`
- JetBrains Mono and Symbols Nerd Font Mono
- Zsh
- Oh My Zsh
- `robbyrussell` theme
- `git` plugin
- `zsh-autosuggestions`
- `zsh-completions`

### Development
- NVM
- latest Node.js LTS + npm
- Python + pip + venv + pipx
- Docker Engine + Buildx + Compose
- Visual Studio Code
- Git / GitHub CLI
- common compilers and development tools

### Desktop apps
- Brave
- Telegram
- Thunderbird
- Postman
- Steam
- Lutris

### System tools
- Flatpak + Flathub
- rclone
- Syncthing
- Solaar
- Input Remapper
- Espanso
- LenovoLegionLinux on Lenovo hardware
- Bitwarden CLI and Desktop

### Virtualization
- KVM
- QEMU
- libvirt
- virt-manager
- UEFI/OVMF
- default `192.168.122.0/24` libvirt NAT network

## Install

```bash
git clone <your-repository-url> linux-setup
cd linux-setup
chmod +x install.sh
./install.sh
```

The installer must be run as your normal user. It uses `sudo` when system changes are required.

After the installer finishes, log out and log back in. This is required for the new login shell and group membership such as `docker`, `libvirt`, and `kvm`.

## Configuration management

The installer links these tracked configuration files into your home directory:

- `configs/zsh/.zshrc` -> `~/.zshrc`
- `configs/espanso/match/base.yml` -> Espanso's `match/base.yml`

If a destination already exists, it is backed up with a timestamp before the symlink is created.

WezTerm is handled differently: the installer clones the public configuration repository directly into `~/.config/wezterm`. If that directory already contains another configuration, it is backed up first.

## Settings

Edit `settings.sh` to disable an individual component. This is not a profile system; it is simply a central set of installer switches.

Examples:

```bash
INSTALL_STEAM=false
INSTALL_LENOVO_LEGION_LINUX=false
INSTALL_CODEX=false
```

### OpenSSH server

```bash
INSTALL_OPENSSH_SERVER=true
ENABLE_OPENSSH_SERVER=true
```

The first switch installs the server package independently of `INSTALL_BASE`.
The second permits the installer to enable/start `sshd.service` or `ssh.service`,
and takes effect only when both switches are true. False values do not stop,
disable, or uninstall an existing server. Distro package scripts may themselves
start services during installation; `ENABLE_OPENSSH_SERVER` controls this
installer's explicit service operations.

Debian/Fedora base manifests retain only the SSH client. Arch's `openssh` package
contains both client and server and remains in its base manifest.

### WezTerm fonts

Fonts are managed whenever `INSTALL_WEZTERM=true`, including when WezTerm is
already installed. The installer prefers distro packages, falls back to pinned
upstream releases under `~/.local/share/fonts/`, refreshes the font cache, and
checks the actual family returned by `fc-match`. Existing fallback files are
reused. Missing fontconfig or unsuccessful font verification produces a warning.

| Family | JetBrains Mono | Symbols Nerd Font Mono |
| --- | --- | --- |
| Debian/Ubuntu | `fonts-jetbrains-mono` | Upstream fallback |
| Fedora | `jetbrains-mono-fonts` | Upstream fallback |
| Arch/CachyOS/Omarchy | `ttf-jetbrains-mono` | `ttf-nerd-fonts-symbols-mono` |

Package names were checked against [Debian](https://packages.debian.org/trixie/fonts-jetbrains-mono),
[Ubuntu](https://packages.ubuntu.com/noble/fonts-jetbrains-mono),
[Fedora](https://packages.fedoraproject.org/pkgs/jetbrains-mono-fonts/jetbrains-mono-fonts/),
and [Arch](https://archlinux.org/packages/extra/any/ttf-nerd-fonts-symbols-mono/).
Fallbacks use [JetBrains Mono 2.304](https://github.com/JetBrains/JetBrainsMono/releases/tag/v2.304)
and [Nerd Fonts 3.4.0 Symbols Only](https://github.com/ryanoasis/nerd-fonts/releases/tag/v3.4.0).

### LenovoLegionLinux

Installation remains gated on Lenovo DMI identification. On Arch-family systems,
the installer checks the boot kernel configuration, then `/proc/config.gz`, with
CachyOS as a fallback, and installs `clang`, `llvm`, and `lld` for Clang kernels.
Kernel headers and DKMS setup remain in place, with explicit success/failure
messages. Secure Boot still requires any necessary signing/MOK enrollment to be
handled manually.

The Python package from the source checkout is installed with pipx in a user
virtual environment that can reuse distro Python dependencies. Reruns refresh
that environment. Both `legion_cli` and `legion_gui` are checked on PATH after
installation; failures warn without undoing or aborting the separate DKMS setup.
The default command directory is `~/.local/bin` (already in the tracked Zsh config).
For a custom `PIPX_BIN_DIR`, add that directory to your shell's PATH yourself.
Launch the GUI with `legion_gui`; this setup does not install global desktop or
polkit files from the pipx environment. Hardware access still depends on the
driver and upstream privilege requirements.

Pillow dependencies are `python3-pil` on [Debian](https://packages.debian.org/trixie/python3-pil)/[Ubuntu](https://packages.ubuntu.com/noble/python3-pil),
`python3-pillow` on [Fedora](https://packages.fedoraproject.org/pkgs/python-pillow/python3-pillow/),
and `python-pillow` on [Arch](https://archlinux.org/packages/extra/x86_64/python-pillow/).
Fedora uses `python3-pyqt6` for Qt. The commands, dependencies, and bundled icons
are defined in [upstream packaging](https://github.com/johnfanv2/LenovoLegionLinux/blob/main/python/legion_linux/setup.cfg).

### Libvirt network

The installer uses `qemu:///system`, creates the default NAT network only when
missing, starts it only when inactive, enables autostart, and verifies both final
states. Existing networks are never redefined. Connection, definition, start,
autostart, and verification failures produce visible warnings.

## Package manifests

Simple package lists live in `packages/`; parsing and installation are handled by
`lib/packages.sh` using the package-manager helpers in `lib/common.sh`. Complex
installers, repository setup, services, and configuration remain in `modules/`.
Small package calls tied to individual component switches also remain there.

- `common.txt` and `debian.txt`, `fedora.txt`, or `arch.txt` contain base tools.
- `build-common.txt` and `build-<family>.txt` contain compiler/build dependencies.
  Like the base tools, these still follow `INSTALL_BASE`.
- `development-<family>.txt` contains Python tooling, controlled by `INSTALL_PYTHON`.
- `virtualization-*`, `legion-*`, and `espanso-build-arch.txt` hold dependencies
  used only by the corresponding module and its existing installation conditions.

Common manifests contain names shared by all three families; family manifests
contain the remaining packages. Ubuntu uses `debian`; CachyOS and Omarchy use
`arch`. No profiles are added.

To add a package, put its name on its own line in the appropriate manifest. Use
the common file when the name is identical across all supported families, or put
each distro's name in the corresponding family file. For example, `fd-find`
appears in the Debian and Fedora base manifests, while Arch uses `fd`.
New manifest files must also be wired into their owning module.

Blank lines and full-line `#` comments are allowed. Surrounding whitespace is
trimmed and duplicate names are installed only once per manifest, in first-seen
order. Keep checked-in files free of duplicates and trailing whitespace; the
tests enforce this. Entries are package names, never shell commands or inline
comments. Missing or invalid manifests fail before any of their packages install.
Already installed packages are skipped; unavailable packages produce warnings.
Installation reuses the existing per-package checks and transactions.

Run the lightweight checks without installing any packages:

```bash
./tests/test-syntax.sh
./tests/test-manifests.sh
./tests/test-terminal.sh
./tests/test-services.sh
./tests/test-virtualization.sh
./tests/test-legion.sh
./tests/test-bitwarden.sh
./tests/test-secrets.sh
```

The manifest tests include mocked Debian, Fedora, and Arch installation paths and
base/Python settings checks. If available, also run
`shellcheck -x -P SCRIPTDIR install.sh restore-secrets.sh lib/*.sh modules/*.sh scripts/* tests/*.sh tests/helpers/*.sh`; ShellCheck is not a
runtime dependency.

The reliability tests mock package managers, downloads, service operations, and
hardware commands. They cover font fallback/reruns, SSH switches, libvirt state
transitions and failures, Lenovo hardware/Clang detection, and pipx/DKMS results.
They do not replace a fresh-install smoke test on each distro and supported hardware.

The Bitwarden tests use a fake CLI, fake sentinel secrets, and disposable homes.
They cover authentication and cleanup, exact lookup, native checksum rejection,
file permissions/atomic replacement, overwrite conflicts, tracing refusal,
secret leakage, and command exit codes. They need Bash, jq, unzip, and standard
Linux utilities; no real vault, downloads, or package installation are used.

## Bitwarden secret management

Bitwarden Password Manager is the backend for personal secrets. Git contains
only code and references in `configs/bitwarden/items.sh`; secret values stay in
the vault until needed by a local file or process. This uses Secure Notes and
custom fields, so encrypted attachments and a paid attachment feature are not
required. It does not use Bitwarden Secrets Manager or chezmoi.

The default settings are:

```bash
INSTALL_BITWARDEN_CLI=true
INSTALL_BITWARDEN_DESKTOP=true
RESTORE_BITWARDEN_SECRETS=true
BITWARDEN_SECRETS_REQUIRED=false
BITWARDEN_OVERWRITE_EXISTING_SECRETS=false
RESTORE_RCLONE_FROM_BITWARDEN=true
BITWARDEN_CLI_INSTALL_METHOD="auto"
BITWARDEN_CLI_VERSION="2026.9.0"
```

`55-bitwarden.sh` installs software without authenticating. `auto` reuses a
working `bw`, otherwise uses `npm install -g @bitwarden/cli` when npm is available
(loading an existing NVM installation when needed). It never uses `sudo npm`.
With a system npm whose global prefix is not writable, use NVM or choose
`BITWARDEN_CLI_INSTALL_METHOD="native"`. An npm installation failure is reported
without silently switching installation methods.

The native fallback supports x86_64 and ARM64. It downloads the pinned release's
metadata from the official `bitwarden/clients` GitHub repository, requires a
SHA-256 asset digest, checks the archive before extracting/executing anything,
and installs `~/.local/bin/bw` with mode `0755`. Missing digests, mismatches, and
unsupported architectures fail this path. Existing installations are reused;
changing `BITWARDEN_CLI_VERSION` does not upgrade an existing CLI. The version
setting applies only to native installation.

Native ARM64 builds and GitHub asset digests were verified for
[CLI 2026.9.0](https://github.com/bitwarden/clients/releases/tag/cli-v2026.9.0).
These supersede the plan's older ARM64/npm-only assumption and separate checksum
file description. See the official [CLI instructions](https://bitwarden.com/help/cli/)
and [checksum verification guidance](https://bitwarden.com/help/security-faqs/#q-how-do-i-validate-the-checksum-of-a-bitwarden-app).

Desktop uses the existing Flatpak helper for `com.bitwarden.desktop`. Missing
Flatpak or a failed Desktop installation produces a warning; restoration uses
the standalone CLI and does not depend on Desktop. Keep `INSTALL_FLATPAK=true`
unless Flatpak and the user Flathub remote are already configured.

### Prepare the vault once

1. Optionally create a folder named `Linux Setup` for organization. This folder
   is not an access-control boundary or lookup filter.
2. Create a **Secure Note** named exactly `Linux Setup - rclone.conf`.
3. Paste the complete current `~/.config/rclone/rclone.conf` into its Notes field.
   Do this in Bitwarden, never in the repository or an issue.
4. Keep item names unique across the accessible vault. Duplicate exact names
   are rejected, even if they are in different folders.

For an EU or self-hosted account, configure the CLI server using Bitwarden's
official CLI instructions before the first restore. Desktop and CLI
authentication are independent.

### Restore and refresh

`80-secrets.sh` restores after the application modules. To refresh after rotating
a credential, adding an rclone remote, or updating the note:

```bash
./restore-secrets.sh
```

Run as your normal user in a terminal. The standalone command honors the same
settings as the installer and requires an already installed `bw` and `jq`.
Disabling `RESTORE_BITWARDEN_SECRETS` disables both entry points. Disabling
`RESTORE_RCLONE_FROM_BITWARDEN` skips the only current file mapping without
prompting. Rclone restoration is independent of `INSTALL_RCLONE`, allowing
restoration when the application is already installed separately.

The CLI prompts for login/MFA or unlock as necessary. Login uses raw output to
capture its new session; an already logged-in locked vault uses `bw unlock
--raw`. A valid inherited session is reused. The scripts do not read your master
password, use API-key login, or save `BW_SESSION`. Synchronization occurs before
lookup. Sessions stay in a subshell and are cleaned on exit, including failures
and handled signals. The scripts re-lock sessions they opened, and leave an
initially unlocked vault unlocked. Avoid concurrent CLI use while a restore owns
a session. Bitwarden itself maintains its normal encrypted local vault cache.

Secret entry points refuse `bash -x`. Do not enable tracing around manually
exported sessions either. Login/unlock needs terminal stdin and stderr; a valid
inherited session can be used without prompts. Never save sessions in shell
startup files or session files.

The rclone file is restored atomically with mode `0600`, preserving exact note
bytes, including trailing newlines. Identical content is left in place and its
mode is corrected if necessary. Differing content is preserved with a warning
unless `BITWARDEN_OVERWRITE_EXISTING_SECRETS=true`; replacement creates no
plaintext backup. Symlink paths, hard-linked/non-regular destinations, and a
destination directory writable by other users are refused. Temporary plaintext
files have restrictive permissions and are removed on normal exits and handled
signals; forcibly killed processes or power loss cannot run cleanup traps.

With `BITWARDEN_SECRETS_REQUIRED=false`, failures warn and allow setup to
continue; the standalone command also returns success after that warning.
Set it to `true` when automation must receive a failing exit status, including
when an existing differing file was preserved. No success message claims a
conflicting file was restored.

Verify without displaying credentials:

```bash
bw --version
bw status
rclone listremotes
# Optional read-only check, if your remote is named b2:
rclone lsd b2:
```

### One process receives one API key

Create a unique item such as `Linux Setup - OpenAI`, with a custom hidden field
named `api_key`. Store the actual key only in that field. Invoke:

```bash
scripts/with-bitwarden-secret \
  "Linux Setup - OpenAI" api_key OPENAI_API_KEY -- command-that-needs-openai
```

The wrapper authenticates, synchronizes, and requires exactly one matching item
and field. Empty/missing/duplicate fields and NUL values fail. It sets the chosen
variable only in the launched command's environment and returns that command's
exit status. It strips Bitwarden session and authentication variables before
launching the child. It never writes API keys into `.zshrc`, `.profile`, `.env`,
or external command arguments. Use application-specific variable names;
shell/loader controls and Bitwarden/internal names are reserved. Only run trusted
commands: the receiving process and its descendants can read or print their
environment. The wrapper's own failures always return nonzero, independently
of the installer's optional-restoration policy.

### SSH keys and intentional exclusions

Open and unlock Bitwarden Desktop, enable **SSH Agent** in its settings, and
import/create your key as an **SSH Key** item. Register the public key with
GitHub or the server. For the Flatpak installation, configure the socket:

```bash
export SSH_AUTH_SOCK="$HOME/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock"
ssh -T git@github.com
```

Add that non-secret socket setting to your shell configuration if desired.
Follow the current [Bitwarden SSH Agent instructions](https://bitwarden.com/help/ssh-agent/)
for other installation formats. GUI agent authorization remains a manual step.
The installer neither writes SSH private keys to disk nor deletes existing keys.

GitHub CLI continues to use `gh auth login`. GitHub PAT restoration, Docker
credential restoration/login, and Syncthing identity restoration are excluded.
Syncthing identities should remain unique per active device. Keep those secrets
in Bitwarden for manual use; no automatic Docker credential strategy is added.

## Secrets

Do not put passwords, API keys, SSH private keys, rclone credentials, browser profiles, or Syncthing private device material in this repository.

`.gitignore` already excludes common private-key and secret paths. Keep machine credentials separate from the public dotfiles/setup repository.

Your Espanso `base.yml` is intentionally tracked because it is part of the supplied personal configuration. Review it before publishing this repository publicly if any snippet contains information you do not want public.

## Docker note

The installer adds the current user to the `docker` group so Docker can be used without `sudo`. Membership in this group effectively grants root-level control of the machine through the Docker daemon. Remove that group assignment if you prefer rootless Docker or `sudo docker`.

## Re-running

The setup is designed to be re-runnable:

- already installed distro packages are skipped
- existing Oh My Zsh and plugins are reused
- the WezTerm config repo is fast-forward updated only when there are no local changes
- existing configs are backed up before first linking
- existing libvirt `default` networking is reused

## Useful checks

```bash
echo $SHELL
nvm --version
node --version
npm --version
python3 --version
docker --version
docker compose version
code --version
virsh net-list --all
espanso --version
```

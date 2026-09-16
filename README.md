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
```

The manifest tests include mocked Debian, Fedora, and Arch installation paths and
base/Python settings checks. If available, also run
`shellcheck install.sh lib/*.sh modules/*.sh tests/*.sh`; ShellCheck is not a
runtime dependency.

The reliability tests mock package managers, downloads, service operations, and
hardware commands. They cover font fallback/reruns, SSH switches, libvirt state
transitions and failures, Lenovo hardware/Clang detection, and pipx/DKMS results.
They do not replace a fresh-install smoke test on each distro and supported hardware.

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

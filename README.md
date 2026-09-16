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
```

The manifest tests include mocked Debian, Fedora, and Arch installation paths and
base/Python settings checks. If available, also run
`shellcheck install.sh lib/*.sh modules/*.sh tests/*.sh`; ShellCheck is not a
runtime dependency.

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

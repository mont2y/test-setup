# Full Implementation Plan: Add Bitwarden Secret Management to `test-setup`

## Goal

Add Bitwarden to `mont2y/test-setup` as the central backend for personal secrets while keeping the public repository free of secret values.

Implement directly on:

```text
main
```

Supported distro families remain:

```text
Ubuntu / Debian          -> debian
Fedora                   -> fedora
Arch / CachyOS / Omarchy -> arch
```

The implementation must remain Bash-based, modular, idempotent, profile-free, settings-driven, and safe for a public GitHub repository.

This plan intentionally does **not** add chezmoi yet. Bitwarden should first integrate directly with the existing setup architecture.

---

## 1. Security model

The public repository may contain installer logic, package manifests, non-secret config, Bitwarden item names, field names, destination paths, tests, and documentation.

It must never contain:

```text
Bitwarden master password
BW_SESSION
BW_CLIENTSECRET
Backblaze B2 application keys
GitHub PATs
Docker tokens
API keys
SSH private keys
real rclone.conf contents
Syncthing private identity material
private certificates
real .env values
```

Architecture:

```text
GitHub public repo
      |
      v
 test-setup
      |
      +--> install Bitwarden CLI/Desktop
      +--> authenticate interactively
      |
      v
 Bitwarden vault
      |
      +--> rclone config
      +--> API keys
      +--> service credentials
      +--> SSH keys
      |
      v
 local machine only
```

---

## 2. Current integration points

Current relevant modules:

```text
00-system.sh
10-shell.sh
20-terminal.sh
30-dev.sh
40-apps.sh
50-tools.sh
60-virtualization.sh
70-legion.sh
90-services.sh
```

Current behavior relevant to this change:

- Node.js/npm are installed in `30-dev.sh` by default.
- Flatpak apps are handled in `40-apps.sh`.
- rclone is installed in `50-tools.sh`.
- GitHub CLI is installed in `30-dev.sh`.
- `~/.local/bin` is already in the tracked Zsh PATH.
- modules run lexically.
- the repo is public.

Bitwarden should fit this structure rather than create a second bootstrap system.

---

## 3. Proposed files

Add:

```text
lib/bitwarden.sh
modules/55-bitwarden.sh
modules/80-secrets.sh
configs/bitwarden/items.sh
scripts/with-bitwarden-secret
restore-secrets.sh
tests/test-bitwarden.sh
tests/test-secrets.sh
```

Do not add any file containing actual secret values.

---

## 4. Settings

Add to `settings.sh`:

```bash
INSTALL_BITWARDEN_CLI=true
INSTALL_BITWARDEN_DESKTOP=true

RESTORE_BITWARDEN_SECRETS=true
BITWARDEN_SECRETS_REQUIRED=false
BITWARDEN_OVERWRITE_EXISTING_SECRETS=false

RESTORE_RCLONE_FROM_BITWARDEN=true
BITWARDEN_CLI_INSTALL_METHOD="auto"
```

Meaning:

- `INSTALL_BITWARDEN_CLI`: install `bw`.
- `INSTALL_BITWARDEN_DESKTOP`: install the GUI/SSH-agent app.
- `RESTORE_BITWARDEN_SECRETS`: run the interactive restore stage.
- `BITWARDEN_SECRETS_REQUIRED`: decide whether restore failures stop the entire setup.
- `BITWARDEN_OVERWRITE_EXISTING_SECRETS`: allow replacement of differing local secret files.
- `RESTORE_RCLONE_FROM_BITWARDEN`: restore the real rclone config.
- `BITWARDEN_CLI_INSTALL_METHOD`: support `auto`, `npm`, and `native`.

Do not add settings for GitHub/Docker automation until those features actually exist.

---

## 5. Bitwarden CLI installation

Bitwarden currently supports:

- native Linux x64 CLI
- npm package: `@bitwarden/cli`
- Snap
- CLI inside the Bitwarden Flatpak desktop package

The current repository already installs Node.js LTS, so npm is a natural primary method.

### Recommended `auto` behavior

```text
bw already exists
  -> skip

npm available
  -> npm install -g @bitwarden/cli

npm unavailable + x86_64
  -> install official native CLI after checksum verification

npm unavailable + ARM64
  -> warn/fail with clear remediation because official docs currently direct ARM64 users to npm
```

Do not make Snap a dependency.

---

## 6. npm installation rules

When npm is available:

```bash
npm install -g @bitwarden/cli
```

Then verify:

```bash
command -v bw
bw --version
```

Do not use `sudo npm` with NVM.

If NVM exists but is not loaded in the current shell, the Bitwarden module may load:

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
```

before deciding npm is unavailable.

---

## 7. Native CLI fallback

For x86_64 without npm:

1. download only from Bitwarden's official release source;
2. verify the official SHA-256 checksum;
3. install to `~/.local/bin/bw`;
4. set mode `0755`;
5. verify `bw --version`;
6. fail the install path on checksum mismatch.

Do not use an unverified downloaded executable.

Do not guess the release URL or checksum format; verify the current official scheme at implementation time.

---

## 8. Bitwarden Desktop

When `INSTALL_BITWARDEN_DESKTOP=true`, install:

```text
com.bitwarden.desktop
```

through the existing Flatpak helper:

```bash
install_flatpak_app com.bitwarden.desktop
```

If Flatpak is unavailable, warn and continue. CLI-based secret restoration must not depend on the desktop app.

The desktop app is primarily for normal Bitwarden use and the Bitwarden SSH Agent.

---

## 9. `modules/55-bitwarden.sh`

Responsibilities:

```text
install Bitwarden CLI
verify bw works
install Bitwarden desktop app if enabled
```

It must **not**:

```text
ask for master password
log in
unlock the vault
retrieve secrets
restore configs
```

Authentication belongs in `80-secrets.sh`.

---

## 10. Bitwarden organization

Use a personal Bitwarden folder named:

```text
Linux Setup
```

This is only organization, not a security boundary.

Recommended unique item names:

```text
Linux Setup - rclone.conf
Linux Setup - OpenAI
Linux Setup - GitHub
Linux Setup - Docker Hub
Linux Setup - Backblaze B2
```

Use Bitwarden's dedicated SSH Key item type for SSH keys when possible.

Do not store the Bitwarden master password anywhere.

---

## 11. rclone design

Store the **complete** `~/.config/rclone/rclone.conf` as a Bitwarden Secure Note.

Recommended item:

```text
Linux Setup - rclone.conf
```

Put the complete config in the item's Notes field.

Restore to:

```text
~/.config/rclone/rclone.conf
```

with mode:

```text
0600
```

Why this is preferred:

- preserves every rclone remote
- preserves future rclone options
- does not require the bootstrap to understand each provider
- avoids secrets in command-line arguments
- does not require a new script change when another rclone remote is added

---

## 12. Avoid secret command arguments

Do not implement patterns such as:

```bash
rclone config create ... key "$SECRET"
some-command --password "$SECRET"
```

because process arguments may be observable.

Prefer:

- stdin
- process-local environment variables
- restrictive temporary files
- direct file writes with mode `0600`

---

## 13. `lib/bitwarden.sh`

Create reusable helpers such as:

```bash
bitwarden_cli_available
bitwarden_status
bitwarden_login
bitwarden_unlock
bitwarden_sync
bitwarden_find_item_exact
bitwarden_get_item_json
bitwarden_get_field
bitwarden_get_notes
bitwarden_restore_note_file
bitwarden_cleanup_session
```

Keep application-specific logic out of the generic library except for a generic "restore note to file" helper.

---

## 14. Authentication flow

For personal fresh-PC bootstrap, use interactive authentication.

Do not use a Bitwarden API key by default.

Expected logic:

```text
bw status
   |
   +-- unauthenticated
   |      -> bw login
   |      -> bw unlock --raw
   |
   +-- locked
   |      -> bw unlock --raw
   |
   +-- unlocked
          -> reuse a valid current session or obtain a fresh process-local session
```

Store the returned unlock token only in process memory:

```bash
export BW_SESSION="..."
```

Never write `BW_SESSION` to disk.

Never add it to `.zshrc` or `.profile`.

Never log it.

---

## 15. Do not handle the master password directly

Allow `bw login` and `bw unlock` to prompt interactively.

Do not do:

```bash
read -s BW_MASTER_PASSWORD
```

Do not put the master password in an environment variable.

Do not pipe the master password from a file.

---

## 16. Session scope

Run restoration inside a subshell where practical:

```bash
restore_bitwarden_secrets() (
    ...
)
```

This keeps `BW_SESSION` from surviving in the parent installer shell.

At the end:

```bash
unset BW_SESSION
```

Record initial vault state. If this module unlocked a previously locked vault, it may lock it again at the end. Do not automatically lock a vault that was already unlocked before the module ran.

---

## 17. xtrace protection

Secret restoration must refuse to run when shell tracing is active.

Detect:

```bash
[[ $- == *x* ]]
```

Reason: `bash -x` can expose expanded secret-bearing commands.

If xtrace is active, skip/fail secret restoration according to the configured failure policy.

---

## 18. Vault synchronization

After login/unlock and before retrieval:

```bash
bw sync
```

A sync failure should follow `BITWARDEN_SECRETS_REQUIRED`.

---

## 19. Exact item lookup

Do not silently accept fuzzy/ambiguous item matches.

Flow:

```text
search candidate items
      |
      v
filter exact .name match
      |
      +-- 0 -> missing item error
      +-- 1 -> retrieve by UUID
      +-- >1 -> ambiguous; refuse
```

Never silently choose the first duplicate.

---

## 20. JSON handling

Use `jq`, already present in the base setup.

Use strict extraction such as:

```bash
jq -er
```

when appropriate.

Never log the complete Bitwarden item JSON because it may contain passwords, notes, and custom fields.

---

## 21. Secure Note retrieval

For `Linux Setup - rclone.conf`, retrieve `.notes`.

Reject:

- missing item
- null notes
- empty notes

unless the mapped secret is explicitly optional.

---

## 22. Safe secret file writes

Use:

```bash
umask 077
```

Restore atomically:

```text
create temp file in destination directory
write secret content
chmod expected mode
rename temp file to destination
```

Always clean temporary files with a trap.

Do not rely on `shred` as a security guarantee on SSDs or copy-on-write filesystems.

---

## 23. Existing local secret behavior

Do not blindly overwrite existing secret files.

For rclone:

### Missing destination

Restore normally.

### Existing file with identical content

Leave it unchanged and report success.

### Existing file with different content and overwrite disabled

Preserve the existing file and warn.

### Existing file with different content and overwrite enabled

Replace atomically.

Do not create plaintext backup copies of old secret files by default because that creates extra copies of credentials on disk.

---

## 24. `configs/bitwarden/items.sh`

Track only non-secret references:

```bash
BITWARDEN_FOLDER_NAME="Linux Setup"

BITWARDEN_RCLONE_ITEM="Linux Setup - rclone.conf"
BITWARDEN_RCLONE_DEST="$HOME/.config/rclone/rclone.conf"
BITWARDEN_RCLONE_MODE="0600"
```

Do not put account email, master password, API tokens, or session values here.

---

## 25. `modules/80-secrets.sh`

Run only when:

```bash
RESTORE_BITWARDEN_SECRETS=true
```

Responsibilities:

1. verify `bw` exists;
2. verify `jq` exists;
3. reject xtrace;
4. inspect Bitwarden status;
5. login interactively if needed;
6. unlock process-locally;
7. run `bw sync`;
8. restore enabled secret-backed files;
9. verify file modes;
10. clean session state;
11. re-lock only if appropriate.

Do not install Bitwarden in this module.

---

## 26. Failure policy

Implement a helper such as:

```bash
bitwarden_secret_failure
```

If:

```bash
BITWARDEN_SECRETS_REQUIRED=true
```

use `die`.

Otherwise use `warn` and let the rest of the Linux setup continue.

---

## 27. rclone restoration verification

After a successful restore, verify:

```bash
test -s "$HOME/.config/rclone/rclone.conf"
```

and verify mode `0600`.

Optionally validate basic rclone readability with:

```bash
rclone listremotes
```

Do not run destructive remote operations.

Do not display the config contents.

---

## 28. SSH private keys

Do **not** restore SSH private keys to `~/.ssh/id_ed25519` by default.

Use:

```text
Bitwarden SSH Key item
+
Bitwarden Desktop SSH Agent
```

Recommended flow:

```text
Bitwarden Desktop
   -> import/create SSH key
   -> enable SSH Agent
   -> configure Linux for Bitwarden agent socket
   -> use SSH/Git normally
```

The installer may install the desktop app but should not automate GUI authorization settings unless Bitwarden exposes an official supported interface.

Do not automatically delete existing local SSH private keys.

---

## 29. README SSH instructions

Document:

```text
1. Open Bitwarden Desktop.
2. Unlock the vault.
3. Enable SSH Agent.
4. Import/store the GitHub or server key as an SSH Key item.
5. Configure Linux to use Bitwarden's agent socket using current Bitwarden instructions.
6. Test with ssh -T git@github.com.
```

Prefer the agent over writing private keys back to disk.

---

## 30. API keys

API keys should remain in Bitwarden and be injected only into the process that needs them.

Do not write API keys into:

```text
~/.zshrc
~/.profile
/etc/environment
tracked .env files
```

Add:

```text
scripts/with-bitwarden-secret
```

Suggested interface:

```bash
with-bitwarden-secret ITEM FIELD ENV_NAME -- COMMAND [ARGS...]
```

Example:

```bash
scripts/with-bitwarden-secret \
  "Linux Setup - OpenAI" \
  api_key \
  OPENAI_API_KEY \
  -- \
  some-command
```

The secret should exist only in the child process environment.

---

## 31. Custom field retrieval

Implement:

```bash
bitwarden_get_field ITEM FIELD
```

Requirements:

- exact item resolution
- exact field name match
- exactly one matching field
- failure on missing/duplicate field
- output only the field value

Callers must capture stdout rather than print it.

---

## 32. `scripts/with-bitwarden-secret`

Requirements:

- validate all arguments
- refuse xtrace
- authenticate/unlock using shared library
- never place the secret in command arguments
- set one environment variable for one child process
- run command
- clean session/secret scope
- return child command exit status

Validate `ENV_NAME` as a legal environment variable name.

---

## 33. GitHub credentials

Preferred Git transport authentication:

```text
Bitwarden SSH Agent
```

Do not automatically restore a GitHub PAT in the first implementation.

Keep normal `gh auth login` for GitHub CLI unless a later reviewed change intentionally integrates a token from Bitwarden.

---

## 34. Docker credentials

Do not automatically restore `~/.docker/config.json` in the first implementation.

Docker may store registry credentials in that file unless a credential helper is configured.

Keep Docker credentials in Bitwarden for now.

A future integration can retrieve a token and pipe it into:

```bash
docker login --password-stdin
```

after choosing a secure Docker credential-helper strategy.

---

## 35. Syncthing identity

Do not automatically restore Syncthing's private device identity on every fresh PC.

A Syncthing identity should normally be unique for each simultaneously active device.

Bitwarden may be used as an emergency backup if desired, but automatic restoration is out of scope.

---

## 36. Bitwarden data-model recommendations

Use the appropriate Bitwarden type:

```text
full config file      -> Secure Note
single secret value   -> custom hidden field
username/password     -> Login item
SSH key               -> SSH Key item
```

Examples of custom fields:

```text
account_id
application_key
api_key
token
username
password
```

---

## 37. Free-tier compatibility

Design around ordinary Bitwarden Password Manager capabilities:

- CLI
- Secure Notes
- custom fields
- normal login items
- SSH Key items/Desktop SSH Agent where supported

Do not design around encrypted file attachments because attachments are a paid feature.

For file-like secrets such as `rclone.conf`, use Secure Notes.

---

## 38. Prevent secret logging

Audit all new code for patterns such as:

```bash
echo "$secret"
printf '%s\n' "$secret"
declare -p
env
printenv
set -x
```

No secret-bearing value may be logged.

Normal messages should be generic:

```text
[OK] Bitwarden CLI available
[OK] Bitwarden vault synchronized
[OK] Restored rclone configuration
```

Never print token prefixes/suffixes.

---

## 39. `.gitignore`

Review current `.gitignore` and add appropriate local-secret patterns such as:

```text
.env
.env.*
*.secret
*.secrets
settings.local.sh
bw-session*
.bitwarden-session*
```

Do not accidentally ignore tracked templates/examples.

---

## 40. Install completion message

Update `install.sh` final output.

Instead of always saying `rclone config`, make it aware of Bitwarden secret restoration.

Suggested guidance:

```text
Bitwarden:
  bw status

rclone:
  rclone listremotes

SSH:
  Open Bitwarden Desktop and enable SSH Agent if SSH keys are stored in Bitwarden.
```

Never print secrets.

---

## 41. README documentation

Add a section:

```text
## Bitwarden secret management
```

Document:

- purpose
- what remains public
- what lives in Bitwarden
- CLI/Desktop installation
- interactive authentication
- `BW_SESSION` safety
- rclone Secure Note setup
- overwrite policy
- SSH Agent approach
- API-key process injection
- intentional exclusions

---

## 42. One-time user setup

Document how to prepare Bitwarden before first restore.

### Folder

Create:

```text
Linux Setup
```

### rclone Secure Note

Name:

```text
Linux Setup - rclone.conf
```

Type:

```text
Secure Note
```

Notes:

```text
paste the complete current ~/.config/rclone/rclone.conf
```

Never paste it into GitHub.

---

## 43. Example API-key item

Example Bitwarden item:

```text
Name: Linux Setup - OpenAI
Custom hidden field: api_key = <stored only in Bitwarden>
```

Usage:

```bash
scripts/with-bitwarden-secret \
  "Linux Setup - OpenAI" \
  api_key \
  OPENAI_API_KEY \
  -- \
  command-that-needs-openai
```

README examples must use placeholders only.

---

## 44. Bitwarden API-key login

Bitwarden supports:

```bash
bw login --apikey
```

but do not use it by default for personal fresh-PC setup because it creates another long-lived secret pair:

```text
BW_CLIENTID
BW_CLIENTSECRET
```

Interactive authentication is preferred.

API-key login may be documented later for unattended automation.

---

## 45. Git-history secret scan

Before committing, search the repo for accidentally committed credentials/patterns such as:

```text
application_key
BEGIN OPENSSH PRIVATE KEY
ghp_
github_pat_
AWS_SECRET_ACCESS_KEY
BW_SESSION
BW_CLIENTSECRET
```

If a real secret was ever committed, deleting it in a new commit is insufficient. Rotate the credential first; then clean history if needed.

---

## 46. `restore-secrets.sh`

Add a standalone command:

```bash
./restore-secrets.sh
```

Purpose: restore/refresh Bitwarden-backed secrets without rerunning the full OS bootstrap.

It should source the same shared libraries and call the same restore function as `80-secrets.sh`.

Do not duplicate secret logic.

Useful after:

```text
credential rotation
new rclone remote
Bitwarden item update
```

---

## 47. Recommended module order

```text
00-system.sh
10-shell.sh
20-terminal.sh
30-dev.sh
40-apps.sh
50-tools.sh
55-bitwarden.sh
60-virtualization.sh
70-legion.sh
80-secrets.sh
90-services.sh
```

Reasoning:

```text
30-dev       -> Node/npm available
40-apps      -> Flatpak available
50-tools     -> rclone available
55-bitwarden -> bw available
80-secrets   -> dependent apps already installed
```

---

## 48. Tests: Bitwarden library

Create `tests/test-bitwarden.sh`.

Mock `bw` and test:

```text
unauthenticated
locked
unlocked
login failure
unlock failure
sync failure
```

Also test:

- exact item matching
- missing item
- duplicate exact item
- custom field lookup
- missing field
- duplicate field
- notes retrieval
- session cleanup
- previously unlocked vault not forcibly locked

---

## 49. Mandatory secret-leakage test

Use a fake sentinel:

```text
SUPER_SECRET_SENTINEL_12345
```

Return it from mocked Bitwarden calls.

Capture logs and assert:

```bash
! grep -q 'SUPER_SECRET_SENTINEL_12345' "$log"
```

This test is mandatory.

---

## 50. rclone restore tests

Create `tests/test-secrets.sh` with a disposable HOME.

### Destination missing

Expected:

```text
file created
correct content
mode 0600
```

### Destination identical

Expected:

```text
success
no destructive rewrite needed
```

### Destination differs + overwrite false

Expected:

```text
existing file preserved
warning emitted
```

### Destination differs + overwrite true

Expected:

```text
atomic replacement
mode 0600
```

### Empty note

Expected:

```text
refuse replacement
```

### Bitwarden unavailable

Expected behavior follows `BITWARDEN_SECRETS_REQUIRED`.

---

## 51. xtrace test

Run secret restoration with xtrace enabled.

Expected:

```text
restore does not proceed
warning/error emitted
secret not leaked
```

---

## 52. CLI installation tests

Cover:

```text
bw already installed
npm available
NVM load path
x86_64 native fallback
ARM without npm
download failure
checksum mismatch
successful native install
```

Checksum mismatch must prevent installation.

---

## 53. Desktop install test

When `INSTALL_BITWARDEN_DESKTOP=true`, verify:

```bash
install_flatpak_app com.bitwarden.desktop
```

is called.

When false, no Bitwarden desktop install should occur.

---

## 54. Process-injection tests

For `scripts/with-bitwarden-secret`, verify:

- secret reaches child environment
- secret does not remain in parent shell
- secret is not logged
- item/field validation works
- child exit code is propagated
- session cleanup occurs

---

## 55. Existing test suite

All current tests must still pass:

```bash
./tests/test-syntax.sh
./tests/test-manifests.sh
./tests/test-terminal.sh
./tests/test-services.sh
./tests/test-virtualization.sh
./tests/test-legion.sh
```

Add:

```bash
./tests/test-bitwarden.sh
./tests/test-secrets.sh
```

If ShellCheck is installed:

```bash
shellcheck install.sh restore-secrets.sh lib/*.sh modules/*.sh scripts/* tests/*.sh
```

---

## 56. Idempotence requirements

A second run must be safe.

Expected:

```text
bw already installed
 -> do not break or duplicate install

Desktop already installed
 -> existing Flatpak helper handles it

already logged in
 -> do not force new login

vault locked
 -> unlock interactively

rclone config identical
 -> leave unchanged

rclone config differs
 -> preserve unless overwrite explicitly enabled
```

---

## 57. Secret rotation workflow

When a credential changes:

```text
update Bitwarden item
run ./restore-secrets.sh
```

No Git commit should be necessary.

For rclone:

```text
update Secure Note
run restore-secrets
```

---

## 58. Fresh-PC experience

Expected user flow:

```bash
git clone <repo>
cd test-setup
./install.sh
```

During setup:

```text
software installs
 -> Bitwarden CLI installs
 -> Bitwarden Desktop installs
 -> secret restore stage starts
 -> bw login if needed
 -> bw unlock
 -> bw sync
 -> rclone.conf restored
 -> session cleaned
 -> setup finishes
```

Bitwarden authentication remains a deliberate manual security boundary.

---

## 59. Verification commands

After installation:

```bash
bw --version
bw status
rclone listremotes
```

For the existing B2 remote:

```bash
rclone lsd b2:
```

Do **not** verify by printing `rclone.conf`.

After Bitwarden SSH Agent setup:

```bash
ssh -T git@github.com
```

---

## 60. Likely existing files to modify

```text
settings.sh
install.sh
README.md
.gitignore
modules/40-apps.sh
```

Possibly `modules/30-dev.sh` only if shared NVM-loading logic is required. Prefer keeping Bitwarden-specific logic in `55-bitwarden.sh`.

---

## 61. New files

```text
lib/bitwarden.sh
modules/55-bitwarden.sh
modules/80-secrets.sh
configs/bitwarden/items.sh
scripts/with-bitwarden-secret
restore-secrets.sh
tests/test-bitwarden.sh
tests/test-secrets.sh
```

---

## 62. Implementation order

### Phase 1 — baseline

```bash
git checkout main
git pull --ff-only
git status
```

Run the existing tests first.

### Phase 2 — Bitwarden installation

Implement settings, `55-bitwarden.sh`, CLI installation, Desktop installation, and verification.

### Phase 3 — Bitwarden library

Implement status/login/unlock/sync/item/field/note/session helpers and tests.

### Phase 4 — rclone restore

Implement Secure Note restore, atomic file writes, permissions, overwrite policy, and tests.

### Phase 5 — process-scoped API secret helper

Implement `scripts/with-bitwarden-secret` and tests.

### Phase 6 — SSH documentation

Document Bitwarden SSH Agent. Do not export SSH private keys to disk by default.

### Phase 7 — docs/final output

Update README, `.gitignore`, and installer completion message. Run the full suite.

---

## 63. Acceptance criteria

### Installation

- [ ] `INSTALL_BITWARDEN_CLI` exists.
- [ ] `INSTALL_BITWARDEN_DESKTOP` exists.
- [ ] `bw` installs when enabled.
- [ ] CLI installation is verified.
- [ ] native binary downloads are checksum verified.
- [ ] desktop installation uses existing Flatpak helper.
- [ ] reruns are safe.

### Authentication

- [ ] unauthenticated state prompts login.
- [ ] locked state prompts unlock.
- [ ] master password is never handled by repo code.
- [ ] `BW_SESSION` is never written to disk.
- [ ] `BW_SESSION` is never logged.
- [ ] `bw sync` runs before restore.
- [ ] session cleanup occurs.

### Retrieval

- [ ] exact item lookup is enforced.
- [ ] duplicates are rejected.
- [ ] missing fields fail clearly.
- [ ] full item JSON is never logged.
- [ ] secret values are never printed.

### rclone

- [ ] complete rclone config is stored in a Secure Note.
- [ ] restore destination is `~/.config/rclone/rclone.conf`.
- [ ] resulting mode is `0600`.
- [ ] atomic write is used.
- [ ] differing existing file is preserved by default.
- [ ] overwrite requires explicit setting.
- [ ] `rclone listremotes` can validate the result.
- [ ] no rclone credential is placed in process arguments.

### SSH

- [ ] Bitwarden Desktop install is supported.
- [ ] SSH keys prefer Bitwarden SSH Key items.
- [ ] private SSH keys are not restored to disk by default.
- [ ] README documents SSH Agent setup.

### API keys

- [ ] API keys remain in Bitwarden.
- [ ] `with-bitwarden-secret` provides process-only injection.
- [ ] no API key is added to `.zshrc` or `.profile`.

### Security

- [ ] restore refuses xtrace.
- [ ] sentinel leakage test passes.
- [ ] `.gitignore` protects common local secret files.
- [ ] no master password/API login credentials are stored in repo.
- [ ] no session is persisted.
- [ ] tests/docs contain fake placeholders only.

### Tests

- [ ] all existing tests pass.
- [ ] `test-bitwarden.sh` passes.
- [ ] `test-secrets.sh` passes.
- [ ] `bash -n` passes.
- [ ] ShellCheck passes when available.

---

## 64. Suggested commit sequence

```text
feat: add Bitwarden CLI and desktop installation

feat: add Bitwarden vault helper library

feat: restore rclone config from Bitwarden

feat: add process-scoped Bitwarden secret injection

test: cover Bitwarden authentication and secret handling

docs: document Bitwarden secrets workflow
```

---

## 65. Codex instructions

1. Work directly on `main`.
2. Inspect current repository state before editing.
3. Run current tests before making changes.
4. Verify current official Bitwarden CLI installation details before coding native downloads.
5. Do not guess native CLI release URLs or checksums.
6. Prefer npm when Node/npm is available.
7. Do not use `sudo npm`.
8. Never handle the Bitwarden master password directly.
9. Never persist `BW_SESSION`.
10. Never log secret values.
11. Refuse secret restore under xtrace.
12. Use exact item resolution.
13. Reject duplicate item matches.
14. Use strict JSON extraction.
15. Restore secret files atomically.
16. Use restrictive permissions.
17. Do not create plaintext backup copies of secret files.
18. Do not restore SSH private keys to disk by default.
19. Prefer Bitwarden SSH Agent for SSH keys.
20. Do not automatically restore Syncthing identity.
21. Do not automatically configure Docker credentials yet.
22. Do not add chezmoi in this implementation.
23. Preserve the existing modular architecture.
24. Keep behavior settings-driven.
25. Preserve all supported distros.
26. Do not introduce profiles.
27. Do not refactor unrelated modules.
28. Add tests for security-sensitive paths.
29. Use fake secrets only in tests.
30. At completion report files changed/added, install method, authentication flow, restored secrets, tests, and remaining manual steps.

---

## 66. Current official references

Verify against current official documentation during implementation:

```text
Bitwarden Password Manager CLI:
https://bitwarden.com/help/cli/

Bitwarden SSH overview:
https://bitwarden.com/help/about-ssh/

Bitwarden SSH Agent:
https://bitwarden.com/help/ssh-agent/

Bitwarden custom fields:
https://bitwarden.com/help/custom-fields/
```

If official documentation conflicts with this plan, current official Bitwarden behavior takes precedence.

---

## 67. Intended end state

```text
./install.sh
   |
   +--> install system/apps
   +--> install Bitwarden CLI
   +--> install Bitwarden Desktop
   +--> authenticate interactively
   +--> sync vault
   +--> restore rclone.conf securely
   +--> clean Bitwarden session
   +--> finish setup
```

For API-key commands:

```text
with-bitwarden-secret
   -> unlock
   -> retrieve exact item/field
   -> set env for one child process
   -> run child
   -> remove secret/session scope
```

For SSH:

```text
Git / SSH
   -> Bitwarden Desktop SSH Agent
   -> encrypted SSH Key item in Bitwarden
```

Core principle:

```text
Git stores instructions and references.
Bitwarden stores secrets.
Secrets reach only the local process or local file that actually needs them.
```

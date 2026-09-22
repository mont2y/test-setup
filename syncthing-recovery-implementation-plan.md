# Full Implementation Plan: Automated Syncthing Recovery

## Goal

Add safe, repeatable Syncthing recovery to `mont2y/test-setup` so a fresh Linux machine can automatically rebuild its desired Syncthing device/folder topology **without cloning an old Syncthing device identity**.

Implement directly on `main`.

Supported families:

- Ubuntu / Debian -> `debian`
- Fedora -> `fedora`
- Arch / CachyOS / Omarchy -> `arch`

The implementation must remain Bash-based, modular, idempotent, profile-free, safe to rerun, compatible with the existing Bitwarden integration, safe for a public repository, additive by default, and non-destructive.

---

## 1. Core Security Principle

Never restore or clone Syncthing's machine identity from another active device.

Do **not** back up or restore:

```text
key.pem
cert.pem
https-key.pem
https-cert.pem
config.xml
Syncthing index/database
GUI API keys
CSRF/runtime state
```

On a new computer:

```text
Syncthing generates fresh key/certificate
        |
        v
new unique Device ID
        |
        v
recovery applies trusted peers
        |
        v
recovery applies folder IDs / paths
        |
        v
existing peer accepts the new Device ID
        |
        v
synchronization begins
```

The recovery feature restores **topology/configuration intent**, not identity.

---

## 2. Why Identity Must Be Fresh

Syncthing Device IDs are derived from each device's cryptographic identity. Two active machines must not share the same private identity.

Cloning `key.pem` / `cert.pem` would make two machines appear as the same Syncthing device.

The recovery feature must therefore recreate only:

- known remote devices
- friendly peer names
- optional introducer setting
- folder IDs
- folder labels
- folder paths
- folder types
- folder-to-peer sharing relationships

It must never restore the old local Device ID or the old `config.xml`.

---

## 3. Use Bitwarden for Recovery Metadata

The repo already has Bitwarden support.

Create a Bitwarden **Secure Note** named exactly:

```text
Linux Setup - Syncthing Recovery
```

Store a JSON recovery manifest there.

Why Bitwarden:

- the repo is public;
- peer Device IDs are not private keys, but are personal identifiers;
- folder labels/paths reveal private topology;
- Bitwarden is already part of the bootstrap;
- the local Device ID must not be stored there.

The note must never contain:

- Syncthing private key
- Syncthing certificate
- local/fresh Device ID
- `config.xml`
- GUI API key
- Syncthing database

---

## 4. Recovery Manifest Schema

Schema version 1:

```json
{
  "version": 1,
  "devices": [
    {
      "alias": "primary",
      "deviceID": "AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG-HHHHHHH",
      "name": "Primary PC",
      "introducer": false
    }
  ],
  "folders": [
    {
      "id": "workout",
      "label": "Workout",
      "path": "{HOME}/Sync/workout",
      "type": "sendreceive",
      "devices": ["primary"]
    }
  ]
}
```

The real peer Device IDs and real folder topology belong only in Bitwarden.

---

## 5. Add Example Manifest

Create:

```text
configs/syncthing/recovery.example.json
```

Use fake/non-working Device IDs.

The example exists only to document the schema and must never contain real personal IDs.

---

## 6. Manifest Validation

Require:

```json
"version": 1
```

Reject unsupported/missing versions.

### Device rules

Each device:

```json
{
  "alias": "primary",
  "deviceID": "...",
  "name": "Primary PC",
  "introducer": false
}
```

Validation:

- `alias` required and unique
- alias regex: `^[A-Za-z0-9_-]{1,32}$`
- `deviceID` required and unique
- canonical Device ID format expected
- suggested regex: `^[A-Z0-9]{7}(-[A-Z0-9]{7}){7}$`
- `deviceID` must not equal current local Device ID
- `name` required/nonempty
- `introducer` boolean

### Folder rules

Each folder:

```json
{
  "id": "workout",
  "label": "Workout",
  "path": "{HOME}/Sync/workout",
  "type": "sendreceive",
  "devices": ["primary"]
}
```

Validation:

- folder ID required and unique
- suggested ID regex: `^[A-Za-z0-9._-]{1,128}$`
- label required/nonempty
- path required
- type must be supported
- device aliases must all exist
- no duplicate aliases in a folder

Allowed initial folder types:

```text
sendreceive
sendonly
receiveonly
receiveencrypted
```

Verify the installed Syncthing version accepts each type before implementing.

---

## 7. Safe Path Policy

Schema v1 supports `{HOME}` as the only variable placeholder.

Example:

```text
{HOME}/Sync/workout
```

Resolve it without `eval`.

Default path rules:

- resolve to an absolute path
- path must be below `$HOME`
- reject `/`
- reject `$HOME` itself
- reject unresolved placeholders
- prevent traversal escaping `$HOME`

Add to `settings.sh`:

```bash
SYNCTHING_RECOVERY_ALLOW_PATHS_OUTSIDE_HOME=false
```

If false, reject `/mnt`, `/media`, `/srv`, etc.

If true, allow validated absolute external paths.

Use `realpath -m` or an equivalent canonicalization method.

---

## 8. Non-Empty Folder Safety

If a folder is not already configured in Syncthing and its target filesystem directory is non-empty, default behavior is to refuse automatic creation.

Add:

```bash
SYNCTHING_RECOVERY_ALLOW_NONEMPTY_NEW_FOLDERS=false
```

If false:

```text
warn/fail
leave files untouched
do not add folder
```

If true:

```text
allow explicit recovery into the existing non-empty path
```

Recovery must never delete files.

---

## 9. Add Settings

Add:

```bash
RESTORE_SYNCTHING_FROM_BITWARDEN=true

SYNCTHING_RECOVERY_ALLOW_PATHS_OUTSIDE_HOME=false
SYNCTHING_RECOVERY_ALLOW_NONEMPTY_NEW_FOLDERS=false
SYNCTHING_RECOVERY_WAIT_SECONDS=30
```

Existing relevant switches remain:

```bash
INSTALL_SYNCTHING=true
RESTORE_BITWARDEN_SECRETS=true
BITWARDEN_SECRETS_REQUIRED=false
```

Do not add unused switches.

---

## 10. Bitwarden Item Reference

Extend:

```text
configs/bitwarden/items.sh
```

with:

```bash
BITWARDEN_SYNCTHING_RECOVERY_ITEM="Linux Setup - Syncthing Recovery"
```

No real Device IDs or paths belong in this tracked file.

---

## 11. Fresh Identity Generation

Modify Syncthing handling in:

```text
modules/50-tools.sh
```

Before starting the Syncthing user service for managed recovery, explicitly run the current supported equivalent of:

```bash
syncthing generate --no-default-folder
```

Required semantics:

```text
fresh PC -> creates new local identity/config
existing PC -> preserves existing device certificate/identity
```

Syncthing's current documentation states `generate` creates initial setup and leaves an existing device certificate untouched.

This provides the required behavior:

```text
new computer = new Device ID
rerun/existing computer = same Device ID
```

---

## 12. Avoid the Automatic Default Folder

Use `--no-default-folder` for managed recovery.

Reason: desired folders come from the Bitwarden recovery manifest.

Do not delete an already existing default folder on an established machine. The implementation is additive only.

---

## 13. Start the User Service

After generation:

```bash
enable_user_service_if_exists syncthing.service
```

Keep normal user-service management.

If the service unit is unavailable, warn/fail recovery.

Do not launch a background Syncthing process manually with `nohup` or `&`.

---

## 14. New Recovery Library

Create:

```text
lib/syncthing-recovery.sh
```

Suggested functions:

```bash
syncthing_recovery_validate_manifest
syncthing_recovery_resolve_path
syncthing_recovery_wait_ready
syncthing_recovery_local_device_id
syncthing_recovery_apply_device
syncthing_recovery_apply_folder
syncthing_recovery_apply_shares
syncthing_recovery_apply_manifest
syncthing_recovery_print_peer_commands
```

Keep Syncthing logic out of:

```text
lib/common.sh
lib/bitwarden.sh
```

---

## 15. Never Edit `config.xml` Directly

All changes must use:

```bash
syncthing cli ...
```

or another documented Syncthing configuration interface.

Never parse/replace the XML file directly.

Reasons:

- schema evolves;
- it contains machine-specific state;
- it can contain GUI authentication/API information;
- CLI/REST handles active configuration safely.

---

## 16. Service Readiness

Before applying recovery:

```bash
syncthing cli show system
```

must succeed.

Use a bounded loop:

```text
timeout = SYNCTHING_RECOVERY_WAIT_SECONDS
sleep = 1 second
```

If not ready by timeout:

```text
warn/fail
do not begin partial topology changes
```

Retrieve the local ID from:

```bash
syncthing cli show system | jq -er '.myID'
```

or the current documented equivalent.

---

## 17. Local Device ID

The local/current Device ID must be obtained locally after identity generation.

It must never come from:

```text
Git
Bitwarden
old machine backup
```

Validate it.

Reject a manifest peer whose Device ID equals the local ID.

Print the local Device ID at the end because existing peers need to accept it.

---

## 18. Add Trusted Remote Devices

Use the current Syncthing CLI.

Conceptually:

```bash
syncthing cli config devices add   --device-id "$id"   --name "$name"
```

Verify syntax with:

```bash
syncthing cli config devices add --help
```

before coding.

If already present:

- do not delete it
- do not replace addresses
- do not overwrite unrelated options
- keep existing friendly name by default if different

Recovery is additive.

---

## 19. Introducer Support

If manifest says:

```json
"introducer": true
```

enable the peer as an introducer using the current CLI property setter.

Conceptually:

```bash
syncthing cli config devices "$device_id" introducer set true
```

Verify exact current syntax.

If manifest says false:

```text
do not disable an already enabled introducer
```

---

## 20. Do Not Enable `autoAcceptFolders`

Do not automatically enable:

```text
autoAcceptFolders
```

in the first implementation.

The recovery manifest explicitly defines folder IDs and paths. Auto-accept can create folders in unexpected locations.

---

## 21. Existing Folder Detection

Use current CLI commands such as:

```bash
syncthing cli config folders list
syncthing cli config folders "$folder_id" dump-json
```

Verify exact syntax against the installed Syncthing version.

---

## 22. Add Missing Folders

For each absent folder:

1. resolve path;
2. validate path;
3. enforce non-empty directory policy;
4. create directory if missing;
5. add Syncthing folder using the exact existing folder ID.

Conceptually:

```bash
syncthing cli config folders add     --id "$folder_id"     --label "$label"     --path "$resolved_path"     --type "$type"
```

Verify available flags with:

```bash
syncthing cli config folders add --help
```

Folder IDs must match the existing peer's IDs. Do not generate new IDs for recovered existing folders.

---

## 23. Existing Folder Conflict Rules

If same folder ID already exists, inspect its JSON.

Compare:

```text
path
type
```

If path differs:

```text
warn/fail
do not auto-move folder
```

If type differs:

```text
warn/fail
do not auto-change direction/type
```

If label differs:

```text
keep current label
log a concise difference
```

If ID/path/type match:

```text
reuse existing folder
add any missing configured shares
```

---

## 24. Folder Sharing

Resolve each manifest alias to a Device ID.

Ensure the folder includes each configured remote device.

Conceptually:

```bash
syncthing cli config folders "$folder_id" devices add     --device-id "$device_id"
```

If already shared:

```text
skip
```

Do not remove additional existing device shares.

---

## 25. Additive-Only Policy

The first implementation must never automatically:

```text
delete devices
delete folders
remove folder shares
disable introducers
remove unmanaged settings
delete files
delete .stfolder
```

The manifest defines a minimum desired topology, not an exclusive full replacement.

---

## 26. Reuse the Existing Bitwarden Session

Extend:

```text
modules/80-secrets.sh
```

Do not add a second Bitwarden login/unlock flow.

Current module already authenticates once for rclone.

During the same Bitwarden session:

```text
restore rclone
retrieve Syncthing recovery note
apply Syncthing topology
cleanup session once
```

---

## 27. Refactor the Existing Restore Gate

Current `restore_bitwarden_secrets()` returns early when rclone restore is disabled.

Change it so Bitwarden authentication runs when at least one operation is enabled.

Conceptually:

```bash
if [[ "$RESTORE_RCLONE_FROM_BITWARDEN" != true &&
      "$RESTORE_SYNCTHING_FROM_BITWARDEN" != true ]]; then
    return 0
fi
```

---

## 28. Aggregate Recovery Failures

Do not let one recovery block the other.

Conceptually:

```bash
status=0

restore_rclone || status=1
restore_syncthing || status=1

return "$status"
```

Therefore:

```text
rclone conflict -> Syncthing still attempted
Syncthing failure -> rclone result retained
```

The existing:

```bash
BITWARDEN_SECRETS_REQUIRED
```

controls whether aggregate failure stops the full installer.

---

## 29. Do Not Persist the Bitwarden Manifest

Prefer an ephemeral temporary file:

```text
mktemp
umask 077
retrieve note
validate/apply
trap cleanup
```

Do not save the real Syncthing topology into a persistent Git-adjacent file.

The manifest contains personal topology even though it does not contain private keys.

---

## 30. Standalone Refresh

Existing:

```bash
./restore-secrets.sh
```

should rerun:

```text
rclone recovery
Syncthing topology recovery
```

with one Bitwarden authentication session.

Do not duplicate recovery code in a separate standalone implementation.

---

## 31. User Preparation Workflow

On a healthy existing Syncthing peer:

Get peer ID:

```bash
syncthing device-id
```

or:

```bash
syncthing cli show system | jq -r '.myID'
```

List folders:

```bash
syncthing cli config folders list
```

Inspect each folder:

```bash
syncthing cli config folders <FOLDER_ID> dump-json
```

Record only:

```text
trusted peer Device ID
peer name
introducer choice
folder ID
folder label
desired path on fresh Linux PCs
folder type
which peer(s) share it
```

Put that JSON into Bitwarden:

```text
Linux Setup - Syncthing Recovery
```

Do not copy old Syncthing identity files.

---

## 32. Mutual Peer Acceptance

Syncthing trust is mutual.

The fresh PC can configure an existing peer locally, but the existing peer must also add/accept the fresh Device ID.

Do not bypass this property.

After recovery, display:

```text
Fresh Syncthing Device ID:
<NEW_ID>
```

Then generate peer-side commands.

---

## 33. Generate Peer Acceptance Commands

For every configured peer, output commands the user can run on that peer.

Example:

```bash
syncthing cli config devices add   --device-id <NEW_DEVICE_ID>   --name <NEW_HOSTNAME>

syncthing cli config folders workout devices add   --device-id <NEW_DEVICE_ID>
```

Only print folder share commands relevant to that peer.

Use safe shell quoting.

---

## 34. New Device Name

Use:

```bash
hostname
```

or `hostnamectl --static` with a safe fallback.

Do not store the fresh machine's name or Device ID in Bitwarden automatically.

---

## 35. No Remote SSH Mutation in This Feature

Do not:

```text
SSH into peers
run remote Syncthing changes
read remote SSH credentials
auto-accept new device on remote peers
```

Printing commands is allowed.

Remote SSH onboarding can be designed as a separate feature later.

---

## 36. Never Auto-Accept Unknown Pending State

Do not automatically accept all:

```text
pending devices
pending folders
```

Only manifest-defined trusted peers/folders may be configured.

---

## 37. Recovery Summary

At the end, print a concise summary such as:

```text
Syncthing recovery:
  Local Device ID: <ID>
  Trusted peers configured: 1
  Managed folders configured: 2
  Manual peer acceptance required: yes
```

Do not dump full Syncthing config or Bitwarden note JSON.

---

## 38. Optional Read-Only Status Helper

Recommended:

```text
scripts/syncthing-recovery-status
```

It may show:

- local Device ID
- service state
- configured managed peers
- configured managed folders
- folder path/type match status
- connection state where available
- pending counts

It must not mutate configuration.

This helper is optional and should be added only if fully tested.

---

## 39. Update `install.sh`

When Syncthing recovery is enabled, final instructions should mention:

```text
Syncthing:
  Use the newly generated Device ID on the existing peer.
  Run the printed peer-side commands.
  Verify:
    syncthing cli show system
```

Do not display recovery JSON.

---

## 40. README Changes

Add:

```text
## Syncthing recovery
```

Document:

- why identity is never restored
- what is stored in Bitwarden
- recovery JSON schema
- fresh-device identity generation
- folder ID requirement
- path safety
- non-empty-folder safety
- mutual peer acceptance
- additive-only policy
- rerun via `restore-secrets.sh`
- troubleshooting

Prominently document:

```text
Never restore:
key.pem
cert.pem
https-key.pem
https-cert.pem
config.xml
Syncthing database/index
```

---

## 41. Tests

Create:

```text
tests/test-syncthing-recovery.sh
tests/helpers/syncthing-mock.sh
```

Use:

- disposable HOME
- fake Syncthing CLI/service
- fake Bitwarden manifest
- real jq where practical
- no network

### Required test cases

#### Disabled recovery

```bash
RESTORE_SYNCTHING_FROM_BITWARDEN=false
```

Expected:

- no Syncthing Bitwarden note retrieval
- no topology mutation

#### Fresh identity

Expected order:

```text
generate --no-default-folder
service start
recovery CLI
```

Assert no identity/config files are restored.

#### Existing identity

Expected:

- local Device ID unchanged

#### Readiness

Test:

- ready immediately
- ready after retries
- timeout

Timeout must not start partial topology mutation.

#### Manifest validation

Reject:

- missing/unsupported version
- non-array devices/folders
- duplicate aliases
- duplicate peer IDs
- invalid Device ID
- peer ID equals local ID
- duplicate folder IDs
- unknown folder alias
- duplicate alias within folder
- unsupported folder type
- invalid/root/home-root path
- path traversal
- wrong JSON types

#### Device add

Missing device:

```text
add exactly once
```

Rerun:

```text
no duplicate add
```

#### Existing device

Ensure:

- no delete
- no replacement of unrelated options

#### Introducer

`true`:

```text
enable
```

`false`:

```text
do not forcibly disable existing true state
```

#### New empty folder

Verify:

- path created
- exact folder ID used
- label/path/type correct

#### Non-empty new folder

Default false:

- refuse
- leave files untouched

Opt-in true:

- allow

#### Existing matching folder

- reuse
- add missing shares

#### Existing path mismatch

- warn/fail
- do not change path

#### Existing type mismatch

- warn/fail
- do not change type

#### Sharing

- missing share added
- existing share skipped
- unmanaged extra share preserved

#### Unmanaged config

Extra devices/folders/shares remain untouched.

No delete commands may occur.

#### Bitwarden session reuse

With rclone + Syncthing enabled:

```text
one login/unlock
one sync
both attempted
one cleanup
```

#### Aggregate failure

- rclone failure does not prevent Syncthing attempt
- Syncthing failure does not undo rclone result

#### No manifest leakage

Use fake sentinel metadata and ensure full JSON is never logged.

#### Peer commands

Generate only commands relevant to each peer.

#### No remote mutation

Ensure no calls to:

```text
ssh
scp
remote curl
```

#### Identity-file guard

Tests should fail if code tries to read/write:

```text
/key.pem
/cert.pem
/https-key.pem
/https-cert.pem
/config.xml
```

---

## 42. Existing Test Suite

All existing tests must still pass:

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

Add:

```bash
./tests/test-syncthing-recovery.sh
```

If ShellCheck is available:

```bash
shellcheck -x -P SCRIPTDIR   install.sh   restore-secrets.sh   lib/*.sh   modules/*.sh   scripts/*   tests/*.sh   tests/helpers/*.sh
```

---

## 43. Likely Existing Files to Change

```text
settings.sh
install.sh
README.md

modules/50-tools.sh
modules/80-secrets.sh

configs/bitwarden/items.sh

tests/test-secrets.sh
```

---

## 44. New Files

Recommended:

```text
lib/syncthing-recovery.sh
configs/syncthing/recovery.example.json
tests/test-syncthing-recovery.sh
tests/helpers/syncthing-mock.sh
```

Optional:

```text
scripts/syncthing-recovery-status
```

Do not create optional helpers unless they are useful and tested.

---

## 45. Implementation Order

### Phase 1 — Baseline

```bash
git checkout main
git pull --ff-only
git status
```

Run all existing tests.

Verify current Syncthing CLI syntax with `--help`.

### Phase 2 — Schema and Settings

Add:

- settings
- Bitwarden item reference
- fake example JSON
- strict validator

Test validation before mutation logic.

### Phase 3 — Identity Generation

Update `modules/50-tools.sh` to generate local Syncthing identity/config with no default folder before service start.

Test fresh/existing behavior.

### Phase 4 — Recovery Library

Implement:

- service readiness
- local ID
- path validation
- device reconciliation
- folder reconciliation
- folder shares
- peer acceptance commands

All operations additive-only.

### Phase 5 — Bitwarden Integration

Extend `modules/80-secrets.sh`:

- one authentication
- rclone restore
- Syncthing recovery
- aggregate status
- one cleanup

### Phase 6 — Tests

Add complete mocked safety/idempotence tests.

### Phase 7 — Documentation

Document preparation, recovery, manual peer acceptance, and troubleshooting.

---

## 46. Acceptance Criteria

### Identity

- [ ] Fresh PC gets a brand-new Syncthing identity.
- [ ] Existing PC preserves its identity.
- [ ] Local Device ID never comes from Bitwarden.
- [ ] `key.pem` is never restored.
- [ ] `cert.pem` is never restored.
- [ ] `config.xml` is never restored.
- [ ] Syncthing database/index is never restored.

### Manifest

- [ ] Secure Note name is `Linux Setup - Syncthing Recovery`.
- [ ] schema version validated.
- [ ] unique aliases and Device IDs.
- [ ] unique folder IDs.
- [ ] paths validated safely.
- [ ] types validated.
- [ ] aliases referenced by folders must exist.
- [ ] local/remote Device ID collision rejected.

### Configuration

- [ ] missing trusted devices are added.
- [ ] existing devices reused.
- [ ] introducer can be enabled explicitly.
- [ ] missing folders use exact peer folder IDs.
- [ ] matching folders reused.
- [ ] path/type conflicts never auto-corrected.
- [ ] missing shares added.
- [ ] unmanaged config remains untouched.
- [ ] no deletion occurs.

### Filesystem

- [ ] paths below HOME supported.
- [ ] `/` and `$HOME` refused.
- [ ] outside-HOME paths require opt-in.
- [ ] non-empty new folders require opt-in.
- [ ] local files are never deleted.

### Bitwarden

- [ ] existing session reused.
- [ ] no second authentication prompt.
- [ ] rclone and Syncthing both attempted.
- [ ] failures aggregate.
- [ ] recovery JSON not persisted by default.
- [ ] full note never logged.

### Peer acceptance

- [ ] local new Device ID displayed.
- [ ] correct peer-side commands generated.
- [ ] only relevant folder shares printed.
- [ ] no automatic SSH mutation.
- [ ] no blanket pending-device/folder acceptance.

### Quality

- [ ] all prior tests pass.
- [ ] Syncthing recovery tests pass.
- [ ] Bash syntax passes.
- [ ] ShellCheck passes when available.
- [ ] README matches real behavior.
- [ ] no private Syncthing identity enters Git.

---

## 47. Suggested Commit Sequence

```text
feat: define Syncthing recovery manifest schema

feat: generate fresh Syncthing identity for managed recovery

feat: add additive Syncthing topology recovery

feat: restore Syncthing topology from Bitwarden

test: cover Syncthing recovery safety and idempotence

docs: document fresh-device Syncthing recovery
```

---

## 48. Fresh-PC Workflow

Expected final flow:

```text
./install.sh
    |
    +--> install Syncthing
    |
    +--> syncthing generate --no-default-folder
    |       |
    |       +--> new private key/certificate generated locally
    |       +--> new Device ID
    |
    +--> start syncthing.service
    |
    +--> Bitwarden authentication
    |
    +--> retrieve "Linux Setup - Syncthing Recovery"
    |
    +--> add trusted existing peer(s)
    |
    +--> add configured folders with existing folder IDs
    |
    +--> add configured folder/peer relationships
    |
    +--> print new Device ID
    |
    +--> print commands to run on existing peer
```

Existing peer:

```text
add new Device ID
share the corresponding existing folder IDs with it
```

Then Syncthing connects and the fresh machine joins as a brand-new device.

---

## 49. Example Bitwarden Note

```text
Type: Secure Note
Name: Linux Setup - Syncthing Recovery
```

Example Notes:

```json
{
  "version": 1,
  "devices": [
    {
      "alias": "primary",
      "deviceID": "AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG-HHHHHHH",
      "name": "Primary PC",
      "introducer": false
    }
  ],
  "folders": [
    {
      "id": "workout",
      "label": "Workout",
      "path": "{HOME}/Sync/workout",
      "type": "sendreceive",
      "devices": ["primary"]
    }
  ]
}
```

Replace fake peer/folder identifiers with the real values **inside Bitwarden only**.

Never include the fresh PC's Device ID.

---

## 50. Safe Troubleshooting Commands

```bash
systemctl --user status syncthing.service
syncthing device-id
syncthing cli show system | jq -r '.myID'
syncthing cli config devices list
syncthing cli config folders list
syncthing cli config folders <FOLDER_ID> dump-json
```

Never troubleshoot by copying another machine's `config.xml`, `key.pem`, or `cert.pem`.

---

## 51. Codex Instructions

1. Work directly on `main`.
2. Inspect the current repo before editing.
3. Run all current tests first.
4. Verify current Syncthing CLI syntax using `--help`.
5. Prefer current official Syncthing behavior over examples in this plan if syntax changed.
6. Use documented Syncthing CLI/REST interfaces only.
7. Never copy Syncthing private identity files.
8. Never restore the old local Device ID.
9. Never restore `config.xml`.
10. Never restore Syncthing database/index state.
11. Reuse the current Bitwarden session.
12. Do not add a second login/unlock prompt.
13. Do not persist the real recovery manifest by default.
14. Validate the full manifest before mutation.
15. Apply configuration additively.
16. Never delete unmanaged devices/folders/shares.
17. Never auto-accept unknown pending devices.
18. Never auto-accept unknown pending folders.
19. Never SSH to existing peers automatically in this feature.
20. Reject path/type conflicts instead of silently correcting them.
21. Protect non-empty target directories by default.
22. Do not use `eval` for `{HOME}`.
23. Quote every CLI argument.
24. Do not introduce profiles.
25. Do not refactor unrelated modules.
26. Add tests for every destructive-risk path.
27. At completion report:
    - files changed
    - files added
    - exact Syncthing CLI commands used
    - manifest schema implemented
    - tests run
    - test results
    - remaining manual peer-acceptance steps

---

## 52. Final Security Model

```text
Bitwarden
└── desired Syncthing topology
    ├── stable peer Device IDs
    ├── folder IDs
    ├── labels
    ├── paths
    └── folder-to-peer relationships


Fresh PC
└── NEW Syncthing identity
    ├── new private key
    ├── new certificate
    └── new Device ID


Recovery
└── applies Bitwarden topology around the new identity
```

Never:

```text
Old PC key.pem
      |
      X
      |
Fresh PC
```

Always:

```text
Fresh PC
   |
generate locally
   |
new identity
   |
apply topology
```

The key principle is:

```text
Recover relationships and folder intent.
Never recover the device identity itself.
```

## Official References

Verify implementation details against current Syncthing documentation:

- Command-line operation: https://docs.syncthing.net/users/syncthing
- Config REST endpoints: https://docs.syncthing.net/rest/config
- Getting started / Device IDs: https://docs.syncthing.net/intro/getting-started

Important current documented behavior:

- `syncthing generate` can perform initial setup.
- existing device certificates are left untouched by generation.
- `syncthing cli` is intended for automation through the REST API.
- devices must mutually know each other's Device IDs before communicating.
- the same shared folder uses the same folder ID on participating devices.

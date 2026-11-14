# Recover project secrets after a fresh clone

From PowerShell in the repository root:

```powershell
.\secrets.ps1
```

Choose 1 to encrypt, 2 to restore, 3 to verify, or 4 for status. The same operations
are available as `encrypt`, `decrypt`, `verify`, and `status` arguments. You can
run the script by its absolute path from another directory.

```powershell
.\secrets.ps1 encrypt
.\secrets.ps1 decrypt
.\secrets.ps1 verify
python scripts/setup.py
```

Encryption uses your PowerShell profile's `agel` function with the tracked public
recipient in `scripts/config/age-recipient.txt`. The function receives a private
staging `.env` containing the backup, then the tool publishes only encrypted
output. The backend-only `backend/.env.age` is refreshed too, preserving the
existing setup script. A different public key can be selected explicitly with
`-Recipient age1...`. Public recipient keys are safe to commit.

Decrypt and verify prompt for the private `AGE-SECRET-KEY-1...` in the local
terminal with input hidden. The key goes to age over stdin, never an argument or
saved identity file. Alternatively use `-Identity C:\private\identity.agekey`.
Keep the private key outside this repository and keep an independent copy. The
encrypted repository cannot recover its own lost private key.

`decrypt` restores original project-relative paths. Identical files are kept;
different existing files cause a preflight failure before restoring anything.
Use `-Force` only when you intend to replace existing values. Files are staged
under a private ACL on Windows (0700/0600 on POSIX), published after complete age
authentication and rolled back on ordinary publication errors. A process or OS
crash during multi-file publication is not a filesystem-wide atomic transaction;
the committed encrypted backup remains available to rerun restoration.

`verify` decrypts in memory and compares every backed-up file byte-for-byte with
its local counterpart. `status` reports inventory only; it does not assert that
changed contents have been encrypted. Run encrypt after changing credentials,
then commit and push the updated ciphertext and index.

## Included files and Git boundaries

The public [manifest](manifest.json) covers backend/frontend/root environment
files, local Android signing files and project service-account files, plus the
development/production `.secrets` directories and `secrets/local`. The public
index records backed-up file paths and recipient, never secret values. The
authenticated `project.age` bundle contains the contents and restore paths.
An update refuses to silently drop files from the preceding index if they are
missing locally. Restore them first. Retiring a secret needs an intentional
manifest/index change, not an accidental refresh from an incomplete checkout.

Only ignored, untracked plaintext paths may be included. Add future file
locations to the manifest and `.gitignore` before encrypting. Age identities,
example files and ciphertext are excluded. Private scans, databases, build
artifacts, SSH identities and unrelated personal credentials are not swept into
the backup. Remote-only GitHub/Coolify/provider secrets are not recoverable from
an API that cannot reveal them; new project service secrets should be generated
locally here before being installed remotely, then encrypted and pushed.

On other platforms without the PowerShell profile, the equivalent age CLI path
is `python scripts/project_secrets.py encrypt`. Decrypt/verify accept
`--paste-key` or `--identity PATH`; force restore uses `--force`.

## Verification — 14 November 2026

18 integration checks passed locally with real age and throwaway identities,
including the actual Windows profile `agel` function, fresh-file restoration,
binary/CRLF preservation, legacy `.env.age` compatibility, tampering rejection,
preflight conflicts, rollback, missing-file retention, unsafe paths, Git
exclusions and stdin-only private-key handling. The operator's eight current
files were encrypted with the tracked public recipient. Verification with the
operator's existing configured identity also passed for all eight files. Only
age opened the identity file; its contents were never printed or read by the
assistant. You can repeat `verify` locally without changing any files.

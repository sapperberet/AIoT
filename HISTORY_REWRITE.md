HISTORY REWRITE — venv removal
=================================

What happened
-------------
Accidentally the Python virtual environment `grad_project_backend-main/venv` was committed in a prior change (commit message: "modern auth"). That added thousands of files and inflated the repository size, preventing pushes.

What I did
---------
- Created backups before any destructive operation:
  - `C:\\Werk\\AIoT\\aiot_backup_before_filter.bundle` (git bundle of the entire repo)
  - Branch `backup-before-venv` (preserved original history)
  - A mirrored repository and BFG report at `C:\\Werk\\AIoT\\repo-mirror.git` and `C:\\Werk\\AIoT\\repo-mirror.git\\..bfg-report\\...`
- Added `.gitignore` to ignore `grad_project_backend-main/venv/` and removed the venv from the index.
- Rewrote the repository history (using BFG) to remove all folders named `venv` from the entire commit history.
- Replaced `main` with the cleaned history and force-pushed to origin. A safety tag `backup-before-push` and the branch `backup-before-venv` were pushed to origin as recovery points.

Why this is safe
-----------------
- The original history is preserved in the `backup-before-venv` branch and the `aiot_backup_before_filter.bundle` bundle. If anything is missing we can recover from them.

Important: actions for everyone who has a local clone
---------------------------------------------------
Because the repository history was rewritten and `main` was force-updated, any local clones with prior history will diverge. Each contributor should either re-clone or reset their local branches.

Recommended (cleanest): reclone

  git clone https://github.com/sapperberet/AIoT.git

If you must keep local work, save it first and then reset

  git fetch origin
  git checkout main
  git branch save-my-work
  # create save-my-work to preserve any unpushed changes
  git reset --hard origin/main

If you need the pre-clean history

- Checkout the backup branch pushed to origin:

  git fetch origin
  git checkout -b restore-old-history origin/backup-before-venv

Or use the bundle I created:

  git clone aiot_backup_before_filter.bundle repo-from-bundle

Cleanup notes (optional)
------------------------
- I left the mirror and tools in the repo root (for safety):
  - `C:\\Werk\\AIoT\\repo-mirror.git`
  - `C:\\Werk\\AIoT\\tools\\bfg.jar`
  - `C:\\Werk\\AIoT\\aiot_backup_before_filter.bundle`

If you want me to remove those now, tell me and I will remove them.

Contact
-------
If anything looks wrong, or you need me to restore any specific file(s) from the pre-clean history, tell me which files and I will restore them from `backup-before-venv` or the bundle.

-- Automated history-cleaner

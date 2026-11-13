# tutor — AP study corner

A per-machine omp workspace: Socratic tutoring with a 0–5 skill map, local memory,
and AP-exam-style practice. Everything under `~/tutor` is configuration; sessions
and memory stay on each machine in `~/.omp`.

## Set up a student computer (once)

```sh
git clone https://github.com/surya501/tutor.git ~/tutor
~/tutor/setup.sh                 # student mode: locks files, tamper-reset, backup
omp models | grep -i deepseek    # verify model access; if empty, run omp and log in
```

Then open a new terminal and run `tutor`.

On the machine you edit and push from, use `~/tutor/setup.sh --editor` instead
(writable files, no tamper-reset).

## Update a computer

Just run `tutor` — it resets any local edits to instruction files (student
machines), pulls this repo, backs up sessions + memory, then opens.
Manual alternative: `git -C ~/tutor pull`.

## Tamper protection (student machines)

- Instruction files (`AGENTS.md`, config, hook, scripts) are locked read-only.
- Any local edit is discarded on the next `tutor` launch (`git checkout`).
- Changes only ever flow from this repo to student machines.

## Backups

Every `tutor` launch copies the student's sessions and memory bank into the
cloud-drive folder, auto-detected in this order: `~/OneDrive`,
`$USERPROFILE/OneDrive` (Windows), iCloud (`~/Library/Mobile Documents/com~apple~CloudDocs`).
Override with `TUTOR_BACKUP_DIR` (WSL example: `/mnt/c/Users/NAME/OneDrive`).
The memory database is copied through SQLite's online-backup API, so it is safe
while a session is running. Restore = copy the files back and reopen `tutor`.

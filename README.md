# tutor — AP study corner

A per-machine omp workspace: Socratic tutoring with a 0–5 skill map, local memory,
and AP-exam-style practice. Everything under `~/tutor` is configuration; sessions
and memory stay on each machine in `~/.omp`.

## Set up a student computer (once)

Prerequisites: `git`, `zsh` (the macOS default), and omp with model access.

```sh
curl -fsSL https://omp.sh/install | sh   # 1. install omp
omp                                      # 2. first run: complete onboarding
                                         #    and log in — the tutor routes via
                                         #    OpenRouter (DeepSeek); Google and
                                         #    Z.ai keys enable the fallbacks
git clone https://github.com/surya501/tutor.git ~/tutor   # 3. the workspace
~/tutor/setup.sh                         # 4. installs `tutor`, locks files,
                                         #    enables tamper-reset + backup
omp models | grep -iE 'deepseek|glm|gemini'               # 5. verify access
```

Open a new terminal and run `tutor`.

Backups need the machine's cloud drive signed in (OneDrive / iCloud Drive);
without it, backup silently no-ops until it appears.

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

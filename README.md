# tutor — AP study corner

A per-machine omp workspace: Socratic tutoring with a 0–5 skill map, local memory,
and AP-exam-style practice. Everything under `~/tutor` is configuration; sessions
and memory stay on each machine in `~/.omp`.

## Set up a new computer (once)

```sh
git clone <REPO_URL> ~/tutor
~/tutor/setup.sh          # installs the `tutor` command into ~/.zshrc
omp models | grep -i deepseek   # verify model access; if empty, log in: omp
```

Then open a new terminal and run `tutor`.

## Update a computer

Just run `tutor` — it pulls this repo (fast-forward only) before opening.
Manual alternative: `git -C ~/tutor pull`.

## Notes

- Never edit tracked files on student machines; changes come from this repo.
- Sessions, levels, and memory are per machine — two students sharing one
  computer share one memory bank.

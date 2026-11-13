#!/usr/bin/env bash
# ~/tutor setup — safe to run repeatedly.
#   setup.sh            student machine: locks instruction files, installs the
#                       `tutor` command with tamper-reset + backup
#   setup.sh --editor   the machine you edit and push from: writable files,
#                       no tamper-reset (protects uncommitted edits)
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v omp >/dev/null 2>&1; then
	echo "omp is not installed on this machine. Install omp first, then rerun ~/tutor/setup.sh." >&2
	exit 1
fi
if ! command -v git >/dev/null 2>&1; then
	echo "git is not installed. Install git, then rerun ~/tutor/setup.sh." >&2
	exit 1
fi

editor=0
[ "${1:-}" = "--editor" ] && editor=1

lockcmd=""
resetcmd=""
if [ "$editor" -eq 0 ]; then
	# Student machines: discard any local edits to tracked files on every launch,
	# re-lock them read-only (Unix), and back up sessions+memory to the cloud.
	resetcmd=$'\tgit -C ~/tutor checkout -q -- . 2>/dev/null || true\n'
	lockcmd=$'\t( cd ~/tutor && git ls-files -z | xargs -0 chmod a-w 2>/dev/null || true )\n'
fi

rc="${ZDOTDIR:-$HOME}/.zshrc"
touch "$rc"

read -r -d '' block <<EOF || true
# >>> tutor >>>
# tutor — open ~/tutor; with saved topics, pick one from the list (Enter = most recent)
tutor() {
	cd ~/tutor || return
${resetcmd}\tgit -C ~/tutor pull --ff-only --quiet 2>/dev/null || true
${lockcmd}\t~/tutor/backup.sh 2>/dev/null || true
	local -a s=(~/.omp/agent/sessions/-tutor/*.jsonl(N))
	if (( \${#s} )); then omp --resume; else omp; fi
}
# <<< tutor <<<
EOF

sed -i '/^# >>> tutor >>>$/,/^# <<< tutor <<<$/d' "$rc"
printf '\n%s\n' "$block" >>"$rc"

if [ "$editor" -eq 0 ]; then
	( cd ~/tutor && git ls-files -z | xargs -0 chmod a-w 2>/dev/null || true )
	echo "Installed 'tutor' (student mode): instruction files locked read-only,"
	echo "local edits reset on each launch, sessions+memory back up to the cloud."
else
	( cd ~/tutor && git ls-files -z | xargs -0 chmod u+w 2>/dev/null || true )
	echo "Installed 'tutor' (editor mode): files writable, no tamper-reset."
fi
echo "One-time per machine: make sure omp has model access (the tutor models route via OpenRouter)."
echo "Check with: omp models | grep -i deepseek"

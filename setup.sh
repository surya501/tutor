#!/usr/bin/env bash
# ~/tutor setup — safe to run repeatedly.
#   setup.sh            student machine: locks instruction files, installs the
#                       `tutor` and `tutor-web` commands (tamper-reset, backup)
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
	resetcmd='	git -C ~/tutor checkout -q -- . 2>/dev/null || true
'
	lockcmd='	( cd ~/tutor && git ls-files -z | xargs -0 chmod a-w 2>/dev/null || true )
'
fi

rc="${ZDOTDIR:-$HOME}/.zshrc"
touch "$rc"

block=$(cat <<EOF
# >>> tutor >>>
# tutor — open ~/tutor; with saved topics, pick one from the list (Enter = most recent)
tutor() {
	cd ~/tutor || return
${resetcmd}	git -C ~/tutor pull --ff-only --quiet 2>/dev/null || true
${lockcmd}	~/tutor/backup.sh 2>/dev/null || true
	local -a s=(~/.omp/agent/sessions/-tutor/*.jsonl(N))
	if (( \${#s} )); then omp --resume; else omp; fi
}

# tutor-web — the tutor in a browser tab (localhost only). Engine runs in tmux.
tutor-web() {
	command -v tmux >/dev/null 2>&1 || {
		echo "tmux is required: brew install tmux (macOS) / sudo apt install tmux (Linux)"
		return 1
	}
	if ! tmux has-session -t tutor 2>/dev/null; then
		tmux new-session -d -s tutor -c "\$HOME/tutor" "zsh -ic tutor"
	fi
	sleep 2
	(open http://127.0.0.1:7741 2>/dev/null || xdg-open http://127.0.0.1:7741 2>/dev/null) &
	echo "Tutor page: http://127.0.0.1:7741"
	echo "Engine terminal: tmux attach -t tutor   (quit the session with /exit)"
}
# <<< tutor <<<
EOF
)

sed -i '/^# >>> tutor >>>$/,/^# <<< tutor <<<$/d' "$rc"
printf '\n%s\n' "$block" >>"$rc"

if [ "$editor" -eq 0 ]; then
	( cd ~/tutor && git ls-files -z | xargs -0 chmod a-w 2>/dev/null || true )
	echo "Installed 'tutor' + 'tutor-web' (student mode): instruction files locked"
	echo "read-only, local edits reset on each launch, sessions+memory back up to"
	echo "the cloud."
else
	( cd ~/tutor && git ls-files -z | xargs -0 chmod u+w 2>/dev/null || true )
	echo "Installed 'tutor' + 'tutor-web' (editor mode): files writable, no tamper-reset."
fi
echo "One-time per machine: make sure omp has model access (the tutor models route via OpenRouter)."
echo "Check with: omp models | grep -i deepseek"

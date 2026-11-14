#!/usr/bin/env bash
# ~/tutor setup — safe to run repeatedly.
#   setup.sh            student machine: `tutor` opens the web page (engine in
#                       tmux); `tutor-term` is the terminal flow. Files locked,
#                       tamper-reset, backup.
#   setup.sh --editor   the machine you edit and push from: `tutor` is the
#                       terminal flow, `tutor-web` the browser. Files writable,
#                       no tamper-reset (protects uncommitted edits).
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

if [ "$editor" -eq 0 ]; then
	mainline='# tutor — one command: the tutor in your browser.
tutor() { tutor-web; }'
else
	mainline='# tutor — terminal flow (editor machine). tutor-web for the browser.
tutor() { tutor-term; }'
fi

rc="${ZDOTDIR:-$HOME}/.zshrc"
touch "$rc"

block="$(cat <<EOF
# >>> tutor >>>
# tutor-term — the tutor in this terminal; with saved topics, pick one (Enter = most recent)
tutor-term() {
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
		tmux new-session -d -s tutor -c "\$HOME/tutor" "zsh -ic tutor-term"
	fi
	local i
	for i in {1..30}; do
		curl -s -m 1 http://127.0.0.1:7741/boot >/dev/null 2>&1 && break
		sleep 1
	done
	if curl -s -m 1 http://127.0.0.1:7741/boot >/dev/null 2>&1; then
		(open http://127.0.0.1:7741 2>/dev/null || xdg-open http://127.0.0.1:7741 2>/dev/null) &
	else
		echo "Engine didn't start — opening its terminal instead."
		tmux attach -t tutor
	fi
}

${mainline}
# <<< tutor <<<
EOF
)"

sed -i '/^# >>> tutor >>>$/,/^# <<< tutor <<<$/d' "$rc"
printf '\n%s\n' "$block" >>"$rc"

if [ "$editor" -eq 0 ]; then
	( cd ~/tutor && git ls-files -z | xargs -0 chmod a-w 2>/dev/null || true )
	echo "Installed 'tutor' (opens the web page), 'tutor-term', 'tutor-web'"
	echo "(student mode): instruction files locked read-only, local edits reset"
	echo "on each launch, sessions+memory back up to the cloud."
else
	( cd ~/tutor && git ls-files -z | xargs -0 chmod u+w 2>/dev/null || true )
	echo "Installed 'tutor' (terminal), 'tutor-term', 'tutor-web' (editor mode):"
	echo "files writable, no tamper-reset."
fi
echo "One-time per machine: make sure omp has model access (the tutor models route via OpenRouter)."
echo "Check with: omp models | grep -i deepseek"

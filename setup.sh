#!/usr/bin/env bash
# ~/tutor setup — safe to run repeatedly. Installs/updates the `tutor` shell command.
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

rc="${ZDOTDIR:-$HOME}/.zshrc"
touch "$rc"

read -r -d '' block <<'EOF' || true
# >>> tutor >>>
# tutor — open ~/tutor; with saved topics, pick one from the list (Enter = most recent)
tutor() {
	cd ~/tutor || return
	git -C ~/tutor pull --ff-only --quiet 2>/dev/null || true
	local -a s=(~/.omp/agent/sessions/-tutor/*.jsonl(N))
	if (( ${#s} )); then omp --resume; else omp; fi
}
# <<< tutor <<<
EOF

sed -i '/^# >>> tutor >>>$/,/^# <<< tutor <<<$/d' "$rc"
printf '\n%s\n' "$block" >>"$rc"

echo "Installed 'tutor' command into $rc"
echo "One-time per machine: make sure omp has model access (the tutor models route via OpenRouter)."
echo "Run 'omp' once in any folder and check /models, or run: omp models | grep -i deepseek"

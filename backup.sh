#!/usr/bin/env bash
# backup.sh — snapshot the student's tutor sessions + memory bank into the
# cloud-drive folder. Safe to run anytime; silent no-op if no cloud folder.
# Override destination with TUTOR_BACKUP_DIR (e.g. WSL: /mnt/c/Users/X/OneDrive).
set -uo pipefail

dest="${TUTOR_BACKUP_DIR:-}"
if [ -z "$dest" ]; then
	for d in "$HOME/OneDrive" \
		"${USERPROFILE:-}/OneDrive" \
		"$HOME/Library/Mobile Documents/com~apple~CloudDocs"; do
		if [ -d "$d" ]; then dest="$d/tutor-backup"; break; fi
	done
fi
[ -z "$dest" ] && exit 0

mkdir -p "$dest/sessions" "$dest/memory"

agent="${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}"

# Sessions: append-only JSONL — plain copy is safe.
for f in "$agent"/sessions/-tutor/*.jsonl; do
	[ -f "$f" ] && cp -f "$f" "$dest/sessions/" 2>/dev/null
done

# Memory bank: SQLite — use the online-backup API when sqlite3 exists,
# else copy the db plus WAL/SHM sidecars.
for db in "$agent"/memories/mnemopi/banks/tutor-*/mnemopi.db; do
	[ -f "$db" ] || continue
	if command -v sqlite3 >/dev/null 2>&1; then
		sqlite3 "$db" ".backup '$dest/memory/mnemopi.db'" 2>/dev/null
	else
		cp -f "$db" "$dest/memory/" 2>/dev/null
		for side in -wal -shm; do
			[ -f "$db$side" ] && cp -f "$db$side" "$dest/memory/" 2>/dev/null
		done
	fi
done
exit 0

import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";

// Shown once at every session start in ~/tutor (including auto-resumed ones).
// Pure display: no agent turn, no model call.
function reminder(): string {
	const lines = [
		"📚 Welcome back — pick up right where you left off.",
		"",
		'• "teach me ..." — new topic · "quiz me" / "drill me" — practice',
		'• "AP practice" — exam-style mixed set (MCQ + FRQ, rubric-scored)',
		'• "review" / "flashcards" — spaced review · "show progress" — level map',
		'• "just tell me" — skip the Socratic push',
		"• /resume — switch topic · /new — start a fresh one",
	];
	try {
		const text = readFileSync(`${homedir()}/tutor/review.md`, "utf8");
		const today = new Date().toISOString().slice(0, 10);
		let due = 0;
		for (const line of text.split("\n")) {
			const cols = line.split("|").map(c => c.trim());
			if (
				cols.length >= 5 &&
				(cols[1] === "concept" || cols[1] === "card") &&
				/^\d{4}-\d{2}-\d{2}$/.test(cols[3]) &&
				cols[3] <= today
			) {
				due++;
			}
		}
		if (due > 0) lines.push(`⏰ ${due} item${due === 1 ? "" : "s"} due for review — say "review"`);
	} catch {
		// no review.md yet — nothing due
	}
	return lines.join("\n");
}

export default function tutorWelcome(pi: ExtensionAPI) {
	pi.setLabel("Tutor welcome");

	pi.on("session_start", async (_event, ctx) => {
		// Subagent sessions (task/eval clones) rebind factories; skip them.
		if (ctx.agent && ctx.agent.kind !== "main") return;
		pi.sendMessage({
			customType: "tutor-welcome",
			content: reminder(),
			display: true,
			attribution: "agent",
		});
	});
}

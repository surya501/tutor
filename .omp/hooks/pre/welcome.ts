import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

// Shown once at every session start in ~/tutor (including auto-resumed ones).
const REMINDER = [
	"📚 Welcome back — pick up right where you left off.",
	"",
	'• "teach me ..." — new topic · "quiz me" / "drill me" — practice',
	'• "AP practice" — exam-style mixed set (MCQ + FRQ, rubric-scored)',
	'• "show progress" — level map · "just tell me" — skip the Socratic push',
	"• /resume — switch topic · /new — start a fresh one",
].join("\n");

export default function tutorWelcome(pi: ExtensionAPI) {
	pi.setLabel("Tutor welcome");

	pi.on("session_start", async (_event, ctx) => {
		// Subagent sessions (task/eval clones) rebind factories; skip them.
		if (ctx.agent && ctx.agent.kind !== "main") return;
		pi.sendMessage({
			customType: "tutor-welcome",
			content: REMINDER,
			display: true,
			attribution: "agent",
		});
	});
}

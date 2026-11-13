import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { randomUUID } from "node:crypto";

// Tutor web UI — serves the student's quiz page on localhost and exposes an
// `ask_student` tool the tutor calls instead of typing a question. Fully local:
// loopback only, no third-party services. The page must be open for the tool
// to succeed; otherwise the tutor falls back to plain chat.
const PORT = 7741;
const TOKEN = randomUUID();
const POLL_TIMEOUT_MS = 25_000;

interface Pending {
	id: string;
	kind: "mcq" | "free";
	question: string;
	choices?: string[];
	createdAt: number;
	resolve: (answer: string) => void;
}

let pending: Pending | null = null;
let lastPoll = 0;
let listening = false;

function json(res: ServerResponse, body: unknown, status = 200) {
	res.writeHead(status, { "content-type": "application/json" });
	res.end(JSON.stringify(body));
}

function readBody(req: IncomingMessage): Promise<string> {
	const { promise, resolve } = Promise.withResolvers<string>();
	let data = "";
	req.on("data", (chunk: Buffer) => (data += chunk));
	req.on("end", () => resolve(data));
	return promise;
}

const page = () => `<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Tutor</title><style>
:root{color-scheme:dark}
body{font-family:-apple-system,system-ui,sans-serif;background:#1e1e2e;color:#e6e6ef;margin:0;min-height:100vh;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:24px}
#dot{position:fixed;top:14px;right:16px;font-size:13px;opacity:.7}
#card{max-width:560px;width:100%;background:#2a2a3c;border-radius:16px;padding:28px;box-shadow:0 8px 30px rgba(0,0,0,.35)}
#q{font-size:20px;line-height:1.45;margin:0 0 18px;white-space:pre-wrap}
button.choice{display:block;width:100%;text-align:left;font-size:17px;padding:14px 16px;margin:8px 0;border-radius:12px;border:1px solid #44445c;background:#33334a;color:#e6e6ef;cursor:pointer}
button.choice:hover{background:#3d3d58;border-color:#6c6c8f}
textarea{width:100%;box-sizing:border-box;font-size:17px;padding:14px;border-radius:12px;border:1px solid #44445c;background:#33334a;color:#e6e6ef;min-height:110px;resize:vertical}
#send{margin-top:10px;font-size:17px;padding:12px 26px;border-radius:12px;border:none;background:#7aa2f7;color:#1a1a2a;font-weight:600;cursor:pointer}
#wait{opacity:.65;font-size:15px}
</style></head><body>
<div id="dot">● connecting…</div>
<div id="card"><p id="wait">Waiting for your tutor's next question…</p></div>
<script>
let token = "";
const dot = document.getElementById("dot"), card = document.getElementById("card");
async function poll() {
	try {
		const r = await fetch("/poll", { headers: { "x-token": token } });
		const d = await r.json();
		dot.textContent = "● connected";
		render(d.pending);
	} catch { dot.textContent = "○ tutor not running"; }
}
function render(p) {
	if (!p) { card.innerHTML = '<p id="wait">Waiting for your tutor\\'s next question…</p>'; return; }
	if (p.kind === "mcq") {
		card.innerHTML = '<p id="q"></p>' + p.choices.map(() => '<button class="choice"></button>').join("");
		card.querySelector("#q").textContent = p.question;
		card.querySelectorAll("button.choice").forEach((b, i) => {
			b.textContent = p.choices[i];
			b.onclick = () => answer(p.id, p.choices[i]);
		});
	} else {
		card.innerHTML = '<p id="q"></p><textarea id="a" placeholder="Type your answer…"></textarea><button id="send">Send</button>';
		card.querySelector("#q").textContent = p.question;
		card.querySelector("#send").onclick = () => answer(p.id, card.querySelector("#a").value);
		card.querySelector("#a").focus();
	}
}
async function answer(id, text) {
	card.innerHTML = '<p id="wait">Sent ✓ — thinking…</p>';
	await fetch("/answer", { method: "POST", headers: { "content-type": "application/json", "x-token": token }, body: JSON.stringify({ id, answer: text }) });
}
fetch("/boot").then(r => r.json()).then(d => { token = d.token; render(d.pending); setInterval(poll, 2000); poll(); });
</script></body></html>`;

interface PendingPublic {
	id: string;
	kind: "mcq" | "free";
	question: string;
	choices?: string[];
}

export default function tutorWebUI(pi: ExtensionAPI) {
	pi.setLabel("Tutor web UI");

	const server = createServer((req, res) => {
		const url = new URL(req.url ?? "/", `http://127.0.0.1:${PORT}`);
		lastPoll = Date.now();
		if (req.method === "GET" && url.pathname === "/") {
			res.writeHead(200, { "content-type": "text/html; charset=utf-8" });
			return void res.end(page());
		}
		if (req.method === "GET" && url.pathname === "/boot") return json(res, { token: TOKEN, pending: toPublic(pending) });
		if (req.method === "GET" && url.pathname === "/poll") return json(res, { pending: toPublic(pending) });
		if (req.method === "POST" && url.pathname === "/answer") {
			void readBody(req)
				.then(body => {
					const { id, answer } = JSON.parse(body) as { id?: string; answer?: string };
					if (req.headers["x-token"] !== TOKEN) return json(res, { error: "bad token" }, 403);
					if (!pending || pending.id !== id || typeof answer !== "string" || !answer.trim())
						return json(res, { error: "no pending question" }, 404);
					const p = pending;
					pending = null;
					p.resolve(answer.trim().slice(0, 4000));
					return json(res, { ok: true });
				})
				.catch(() => json(res, { error: "bad request" }, 400));
			return;
		}
		return json(res, { error: "not found" }, 404);
	});

	server.on("error", () => {
		listening = false; // port taken (another ~/tutor session) — stay inert
	});
	server.listen(PORT, "127.0.0.1", () => {
		listening = true;
	});
	pi.on("session_shutdown", () => server.close());

	pi.registerTool({
		name: "ask_student",
		label: "Ask the student (web)",
		description:
			"Pose ONE question to the student's browser page. kind=mcq requires 2-5 short choices (no correct-answer hint in wording); kind=free is a text box for short answers. Returns NO_BROWSER when the page is not connected — then ask in plain chat instead and do not retry this tool this turn.",
		parameters: pi.zod.object({
			question: pi.zod.string(),
			kind: pi.zod.enum(["mcq", "free"]),
			choices: pi.zod.array(pi.zod.string()).optional(),
		}),
		async execute(_toolCallId, params, signal) {
			if (!listening || Date.now() - lastPoll > POLL_TIMEOUT_MS) {
				return { content: [{ type: "text", text: "NO_BROWSER" }] };
			}
			if (params.kind === "mcq" && (!params.choices || params.choices.length < 2 || params.choices.length > 5)) {
				return { content: [{ type: "text", text: "ERROR: mcq needs 2-5 choices" }], isError: true };
			}
			const { promise, resolve } = Promise.withResolvers<{ content: { type: "text"; text: string }[] }>();
			const id = randomUUID();
			pending = {
				id,
				kind: params.kind,
				question: params.question,
				choices: params.choices,
				createdAt: Date.now(),
				resolve: answer => resolve({ content: [{ type: "text", text: `STUDENT ANSWER: ${answer}` }] }),
			};
			signal?.addEventListener(
				"abort",
				() => {
					if (pending?.id === id) pending = null;
					resolve({ content: [{ type: "text", text: "CANCELLED by the student" }] });
				},
				{ once: true },
			);
			return promise;
		},
	});
}

function toPublic(p: Pending | null): PendingPublic | null {
	return p && { id: p.id, kind: p.kind, question: p.question, choices: p.choices };
}

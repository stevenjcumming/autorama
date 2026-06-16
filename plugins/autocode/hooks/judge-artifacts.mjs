#!/usr/bin/env node
// judge-artifacts.mjs - optional read-only artifact substance check
//
// Called by on-agent-complete.sh (SubagentStop) when artifact_judge.enabled
// is true in .claude/autocode.yml. Uses the Claude Agent SDK with read-only
// tools to judge whether the completed task's artifact files are
// substantive (real reasoning) rather than unfilled template stubs.
//
// A file-existence check cannot tell a real justification from a stub;
// this judge can, at the cost of tokens. Default off.
//
// Usage: node judge-artifacts.mjs <spec_dir> <task_id>
// Output: one JSON line {"pass": boolean, "reason": string}
// Every failure mode degrades to {"pass": true, ...} so a broken or
// missing SDK never blocks the loop.

const [specDir, taskId] = process.argv.slice(2);

const verdict = (pass, reason) => {
  console.log(JSON.stringify({ pass, reason }));
  process.exit(0);
};

if (!specDir) verdict(true, "no spec dir provided");

try {
  const { query } = await import("@anthropic-ai/claude-agent-sdk");

  const prompt = `Judge the artifact audit trail in ${specDir}/artifacts for task ${taskId || "(unknown)"}.

Use Glob to list artifact files (handoff/handoff.md plus any files matching ${taskId || "T*"}_* under decisions/, assumptions/, risks/, debt/, justifications/), then Read the most relevant ones (at most 5 files).

An artifact is SUBSTANTIVE when its sections contain task-specific reasoning (real file paths, real decisions, real rationale). It is a STUB when headings are followed by blank lines, template placeholder comments, or generic filler.

Respond with ONLY one JSON object, no prose: {"pass": true|false, "reason": "<one sentence>"}. pass=false only when the trail is clearly stub-quality or empty.`;

  let resultText = "";
  for await (const message of query({
    prompt,
    options: {
      allowedTools: ["Read", "Glob"],
      maxTurns: 8,
    },
  })) {
    if (message.type === "result" && message.subtype === "success") {
      resultText = message.result ?? "";
    }
  }

  const match = resultText.match(/\{[\s\S]*\}/);
  if (!match) verdict(true, "judge returned no parseable verdict");
  const parsed = JSON.parse(match[0]);
  verdict(parsed.pass !== false, String(parsed.reason ?? "").slice(0, 300));
} catch (err) {
  verdict(true, `judge unavailable: ${String(err?.message ?? err).slice(0, 200)}`);
}

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
// Model: on-agent-complete.sh passes AUTOCODE_JUDGE_MODEL (read from
// artifact_judge.model in autocode.yml) as an env var; falls back to a
// cheap default here too, so this script never silently runs on an
// expensive default model even if invoked directly (item 7 / roadmap
// 3.4 - no model was pinned before this fix).
//
// Output: one JSON line {"pass": boolean, "reason": string}.
//
// Every failure mode (SDK missing, missing/invalid credentials,
// internal timeout, unparseable verdict) degrades to {"pass": true,
// ...} so a broken or missing SDK never blocks the loop - but unlike
// before, every one of those degrade-to-pass paths is now also logged
// to hook-errors.jsonl (mirroring scripts/lib.sh's log_hook_error JSONL
// shape directly in Node, since this file isn't bash) so a user who
// enables artifact_judge can tell whether it has ever actually run.
//
// Sync vs async: this stays inline/synchronous inside the SubagentStop
// hook (an async detached-process design is a bigger architectural
// change, out of scope here). To avoid being silently SIGKILLed with
// no trace by hooks.json's 60s SubagentStop timeout (on-agent-
// complete.sh, which invokes this script, shares that budget), an
// internal timeout below the hook's budget races the SDK call and
// degrades to a LOGGED timeout instead.

import { appendFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const [specDir, taskId] = process.argv.slice(2);

const HOOK_NAME = "judge-artifacts";
const DEFAULT_MODEL = "claude-haiku-4-5-20251001";
// Stay comfortably under hooks.json's 60s SubagentStop timeout so a
// hang degrades to a logged timeout rather than an untraceable SIGKILL.
const INTERNAL_TIMEOUT_MS = 45_000;
// A substance judge only needs to Glob the artifact files and Read at
// most 5 of them, then emit one JSON verdict (glob, read, respond) -
// 3 turns covers that comfortably without leaving room for an
// unbounded back-and-forth the way the previous maxTurns: 8 did.
const MAX_TURNS = 3;

function logHookError(message, payload) {
  try {
    const dataDir = process.env.CLAUDE_PLUGIN_DATA;
    if (!dataDir) return;
    mkdirSync(dataDir, { recursive: true });
    const entry = {
      timestamp: new Date().toISOString(),
      hook: HOOK_NAME,
      message: String(message).slice(0, 2000),
    };
    if (payload) {
      entry.payload = String(payload).slice(0, 500);
    }
    // JSON.stringify already escapes correctly; no separate
    // json_escape step is needed the way the bash hooks need one.
    appendFileSync(join(dataDir, "hook-errors.jsonl"), `${JSON.stringify(entry)}\n`);
  } catch {
    // Never fail the judge because logging failed.
  }
}

function verdict(pass, reason) {
  console.log(JSON.stringify({ pass, reason }));
  process.exit(0);
}

function degradeToPass(reason, payload) {
  logHookError(reason, payload);
  verdict(true, reason);
}

if (!specDir) {
  degradeToPass("no spec dir provided");
}

// Extract the LAST balanced top-level {...} object from free-form
// model output by tracking brace depth from the start and recording
// each complete top-level object as it closes. A greedy /\{[\s\S]*\}/
// match instead spans from the first "{" to the last "}" in the whole
// response, which breaks the moment the model's prose contains any
// unrelated brace before or after the actual JSON verdict.
function extractLastBalancedJson(text) {
  const objects = [];
  let depth = 0;
  let start = -1;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (ch === "{") {
      if (depth === 0) start = i;
      depth++;
    } else if (ch === "}") {
      if (depth > 0) {
        depth--;
        if (depth === 0 && start !== -1) {
          objects.push(text.slice(start, i + 1));
          start = -1;
        }
      }
    }
  }
  return objects.length ? objects[objects.length - 1] : null;
}

function withTimeout(promise, ms) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(`judge timed out after ${ms}ms`)), ms);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

async function runJudge() {
  let query;
  try {
    ({ query } = await import("@anthropic-ai/claude-agent-sdk"));
  } catch (err) {
    degradeToPass(`judge SDK unavailable: ${String(err?.message ?? err).slice(0, 200)}`);
    return;
  }

  const model = process.env.AUTOCODE_JUDGE_MODEL || DEFAULT_MODEL;

  const prompt = `Judge the artifact audit trail in ${specDir}/artifacts for task ${taskId || "(unknown)"}.

Use Glob to list artifact files (handoff/handoff.md plus any files matching ${taskId || "T*"}_* under decisions/, assumptions/, risks/, debt/, justifications/), then Read the most relevant ones (at most 5 files).

An artifact is SUBSTANTIVE when its sections contain task-specific reasoning (real file paths, real decisions, real rationale). It is a STUB when headings are followed by blank lines, template placeholder comments, or generic filler.

Respond with ONLY one JSON object, no prose: {"pass": true|false, "reason": "<one sentence>"}. pass=false only when the trail is clearly stub-quality or empty.`;

  let resultText = "";
  const runQuery = async () => {
    for await (const message of query({
      prompt,
      options: {
        allowedTools: ["Read", "Glob"],
        maxTurns: MAX_TURNS,
        model,
      },
    })) {
      if (message.type === "result" && message.subtype === "success") {
        resultText = message.result ?? "";
      }
    }
  };

  try {
    await withTimeout(runQuery(), INTERNAL_TIMEOUT_MS);
  } catch (err) {
    const message = String(err?.message ?? err);
    if (message.includes("timed out")) {
      degradeToPass(`judge timed out after ${INTERNAL_TIMEOUT_MS}ms`);
    } else if (/api[_-]?key|credential|unauthorized|authentication/i.test(message)) {
      degradeToPass(`judge missing/invalid credentials: ${message.slice(0, 200)}`);
    } else {
      degradeToPass(`judge query failed: ${message.slice(0, 200)}`);
    }
    return;
  }

  const jsonText = extractLastBalancedJson(resultText);
  if (!jsonText) {
    degradeToPass("judge returned no parseable verdict", resultText);
    return;
  }

  let parsed;
  try {
    parsed = JSON.parse(jsonText);
  } catch (err) {
    degradeToPass(`judge verdict was not valid JSON: ${String(err?.message ?? err).slice(0, 200)}`, jsonText);
    return;
  }

  verdict(parsed.pass !== false, String(parsed.reason ?? "").slice(0, 300));
}

runJudge().catch((err) => {
  degradeToPass(`judge unavailable: ${String(err?.message ?? err).slice(0, 200)}`);
});

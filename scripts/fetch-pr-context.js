#!/usr/bin/env node
// fetch-pr-context.js <PR_NUMBER> <REPO>
// Fetches all PR review comments and the diff.
// Outputs JSON: { "prComments": "<formatted text>", "prDiff": "<diff>" }

import { execFileSync } from "node:child_process";

const prNumber = process.argv[2];
const repo = process.argv[3];
if (!prNumber || !repo) {
  process.stderr.write("Usage: fetch-pr-context.js <PR_NUMBER> <REPO>\n");
  process.exit(1);
}

function gh(...args) {
  try {
    return execFileSync("gh", args, { encoding: "utf8", stdio: ["pipe", "pipe", "pipe"] });
  } catch {
    return "";
  }
}

const inline = gh(
  "api", `repos/${repo}/pulls/${prNumber}/comments`,
  "--jq", '.[] | "[\\(.user.login)] \\(.path):\\(.line // "?") — \\(.body)\n---"',
);

const formal = gh(
  "pr", "view", prNumber, "--repo", repo,
  "--json", "reviews",
  "--jq", '.reviews[]? | "[\\(.author.login) / \\(.state)]\\n\\(.body)\n---"',
);

const topLevel = gh(
  "api", `repos/${repo}/issues/${prNumber}/comments`,
  "--jq", '.[] | "[\\(.user.login)]\\n\\(.body)\n---"',
);

const diff = gh("pr", "diff", prNumber, "--repo", repo);

const prComments = [
  "=== INLINE COMMENTS ===",
  inline || "(none)",
  "",
  "=== FORMAL REVIEWS ===",
  formal || "(none)",
  "",
  "=== TOP-LEVEL COMMENTS ===",
  topLevel || "(none)",
].join("\n");

process.stdout.write(JSON.stringify({ prComments, prDiff: diff || "(no diff)" }));

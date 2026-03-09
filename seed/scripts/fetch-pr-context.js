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

// Determine the latest push timestamp using the head commit's committer.date.
// PR.updated_at advances on any activity (comments, labels, title edits) — not just pushes —
// which would incorrectly drop legitimate review comments via the created_at filter.
let latestPushAt = "1970-01-01T00:00:00Z";
const headSha = gh("api", `repos/${repo}/pulls/${prNumber}`, "--jq", ".head.sha").trim();
if (headSha) {
  const commitDate = gh("api", `repos/${repo}/commits/${headSha}`, "--jq", ".commit.committer.date").trim();
  if (commitDate) latestPushAt = commitDate;
}

const inline = gh(
  "api", "--paginate", `repos/${repo}/pulls/${prNumber}/comments`,
  "--jq", `[.[] | select(.created_at > "${latestPushAt}")] | .[] | "[\\(.user.login)] \\(.path):\\(.line // "?") — \\(.body)\n---"`,
);

const formal = gh(
  "api", "--paginate", `repos/${repo}/pulls/${prNumber}/reviews`,
  "--jq", `[.[] | select(.submitted_at > "${latestPushAt}")] | .[] | "[\\(.user.login) / \\(.state)]\\n\\(.body)\n---"`,
);

const topLevel = gh(
  "api", "--paginate", `repos/${repo}/issues/${prNumber}/comments`,
  "--jq", `[.[] | select(.created_at > "${latestPushAt}")] | .[] | "[\\(.user.login)]\\n\\(.body)\n---"`,
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

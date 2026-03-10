#!/usr/bin/env node
// fetch-fix-context.js <PR_NUMBER> <REPO> <LINEAR_ISSUE_ID>
// Combines fetch-pr-context + fetch-spec into a single JSON output
// for the fixing state's onEnter.

import { execFileSync } from "node:child_process";

const prNumber = process.argv[2];
const repo = process.argv[3];
const issueId = process.argv[4];

if (!prNumber || !repo || !issueId) {
  process.stderr.write("Usage: fetch-fix-context.js <PR_NUMBER> <REPO> <LINEAR_ISSUE_ID>\n");
  process.exit(1);
}

function gh(...args) {
  try {
    return execFileSync("gh", args, { encoding: "utf8", stdio: ["pipe", "pipe", "pipe"] });
  } catch {
    return "";
  }
}

// --- PR context ---
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

// --- PR diff ---
const prDiff = gh("pr", "diff", prNumber, "--repo", repo) || "(no diff)";

// --- Architect spec ---
let architectSpec = "";
const apiKey = process.env.LINEAR_API_KEY;
if (apiKey) {
  try {
    const query = `query($id: String!) { issue(id: $id) { comments { nodes { id body } } } }`;
    const res = await fetch("https://api.linear.app/graphql", {
      method: "POST",
      headers: { Authorization: apiKey, "Content-Type": "application/json" },
      body: JSON.stringify({ query, variables: { id: issueId } }),
    });
    const data = await res.json();
    const nodes = data?.data?.issue?.comments?.nodes ?? [];
    const spec = nodes.find((n) => n.body?.includes("## Implementation Spec"));
    architectSpec = spec?.body ?? "";
  } catch (err) {
    process.stderr.write(`Failed to fetch spec: ${err.message}\n`);
  }
}

process.stdout.write(JSON.stringify({ prComments, prDiff, architectSpec }));

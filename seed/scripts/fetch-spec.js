#!/usr/bin/env node
// fetch-spec.js <LINEAR_ISSUE_ID>
// Fetches the architect spec comment from Linear.
// Outputs JSON: { "architectSpec": "<comment body>" }

const issueId = process.argv[2];
if (!issueId) { process.stderr.write("Usage: fetch-spec.js <LINEAR_ISSUE_ID>\n"); process.exit(1); }

const apiKey = process.env.LINEAR_API_KEY;
if (!apiKey) { process.stderr.write("LINEAR_API_KEY not set\n"); process.exit(1); }

const query = `{
  issue(id: "${issueId}") {
    comments { nodes { id body } }
  }
}`;

const res = await fetch("https://api.linear.app/graphql", {
  method: "POST",
  headers: { Authorization: apiKey, "Content-Type": "application/json" },
  body: JSON.stringify({ query }),
});

const data = await res.json();
const nodes = data?.data?.issue?.comments?.nodes ?? [];
const spec = nodes.find((n) => n.body.includes("## Implementation Spec"));

process.stdout.write(JSON.stringify({ architectSpec: spec?.body ?? "" }));

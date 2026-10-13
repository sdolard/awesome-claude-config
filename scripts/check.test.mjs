import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdtemp, mkdir, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import { GENERATED_MARKER, checkLock, findLeaks, isText } from "./check.mjs";

const sha256 = (text) => createHash("sha256").update(text).digest("hex");

async function fixture(files) {
  const root = await mkdtemp(path.join(tmpdir(), "catalogue-check-"));
  for (const [file, content] of Object.entries(files)) {
    await mkdir(path.dirname(path.join(root, file)), { recursive: true });
    await writeFile(path.join(root, file), content);
  }
  return root;
}

test("findLeaks reports machine paths, node identifiers, addresses and issue numbers", () => {
  const text = [
    "cd /Users/jane/dev/project",
    "projectId=PVT_kwHOAAKFUc4BLmM9",
    "ask jane.doe@corp.example.net",
    "fixed in #2315, see also #12",
    "Co-Authored-By: Someone <noreply@example.com>",
  ].join("\n");
  assert.deepEqual(findLeaks(text), [
    { line: 1, kind: "home-path", match: "/Users/jane/" },
    { line: 2, kind: "github-node-id", match: "PVT_kwHOAAKFUc4BLmM9" },
    { line: 3, kind: "email", match: "jane.doe@corp.example.net" },
    { line: 4, kind: "issue-number", match: "#2315" },
  ]);
});

test("findLeaks accepts placeholders and parameterized commands", () => {
  const text = [
    'PROJECT_ID="<project node id>"',
    "cd ~/dev/project && gh issue view <N>",
    "ls /Users/you/dev /home/username/dev",
    "color: #1234ab; width: 100%",
  ].join("\n");
  assert.deepEqual(findLeaks(text), []);
});

test("checkLock accepts a generated file matching its lock entry", async () => {
  const content = `${GENERATED_MARKER}\n\n# Rule\n`;
  const root = await fixture({ "rules/a.md": content });
  const lock = {
    version: 1,
    entries: [
      { target: "rules/a.md", state: "generated", outputHash: sha256(content) },
    ],
  };
  assert.deepEqual(await checkLock({ root, lock, files: ["rules/a.md"] }), []);
});

test("checkLock rejects a generated file edited by hand", async () => {
  const root = await fixture({
    "rules/a.md": `${GENERATED_MARKER}\n\n# Rule, edited\n`,
  });
  const lock = {
    version: 1,
    entries: [
      {
        target: "rules/a.md",
        state: "generated",
        outputHash: sha256(`${GENERATED_MARKER}\n\n# Rule\n`),
      },
    ],
  };
  assert.deepEqual(await checkLock({ root, lock, files: ["rules/a.md"] }), [
    "rules/a.md: content differs from PROVENANCE.json. Generated files are regenerated from their source, never edited here.",
  ]);
});

test("checkLock rejects a locked file that is missing", async () => {
  const root = await fixture({});
  const lock = {
    version: 1,
    entries: [{ target: "rules/a.md", state: "generated", outputHash: "x" }],
  };
  assert.deepEqual(await checkLock({ root, lock, files: [] }), [
    "rules/a.md: listed in PROVENANCE.json but missing.",
  ]);
});

test("checkLock rejects a marked file absent from the lock", async () => {
  const root = await fixture({ "rules/b.md": `${GENERATED_MARKER}\n` });
  const lock = { version: 1, entries: [] };
  assert.deepEqual(await checkLock({ root, lock, files: ["rules/b.md"] }), [
    "rules/b.md: carries the generated-file marker but is absent from PROVENANCE.json.",
  ]);
});

test("findLeaks reports project field and item identifiers of any shape", () => {
  const text = [
    "fieldId=PVTSSF_lADOANN5s84ACbL0zgBZrZg",
    "fieldId=PVTF_lADOANN5s84ACbL0zgBZrZY",
    "itemId=PVTI_lADOANN5s84ACbL0zgBZrZ0",
    "PR_DESCRIPTION_TEMPLATE and I_AM_A_CONSTANT are plain names",
  ].join("\n");
  assert.deepEqual(
    findLeaks(text).map(({ line, kind }) => ({ line, kind })),
    [
      { line: 1, kind: "github-node-id" },
      { line: 2, kind: "github-node-id" },
      { line: 3, kind: "github-node-id" },
    ],
  );
});

test("checkLock rejects a lock entry with an unknown state", async () => {
  const root = await fixture({ "rules/a.md": `${GENERATED_MARKER}\n` });
  const lock = {
    version: 1,
    entries: [{ target: "rules/a.md", state: "generatd", outputHash: "x" }],
  };
  assert.deepEqual(await checkLock({ root, lock, files: ["rules/a.md"] }), [
    'rules/a.md: unknown state "generatd" in PROVENANCE.json.',
  ]);
});

test("isText keeps any text file whatever its extension and skips binaries", () => {
  assert.equal(isText(Buffer.from("plain notes, no extension\n")), true);
  assert.equal(isText(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x00, 0x1a])), false);
});

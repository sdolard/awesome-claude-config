#!/usr/bin/env node

// Repository check, dependency-free: generated files must match
// PROVENANCE.json, and no file may carry machine- or project-specific data.

import { execFile } from "node:child_process";
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

export const GENERATED_MARKER =
  "<!-- GENERATED FILE: do not edit by hand. Regenerated from a reference configuration; see PROVENANCE.json. -->";

const LOCK_STATES = new Set(["generated", "adopted"]);

// Files that quote the patterns below in order to define or test them.
const SELF = new Set(["scripts/check.mjs", "scripts/check.test.mjs"]);

const LEAK_PATTERNS = [
  {
    kind: "home-path",
    pattern: /\/(?:Users|home)\/(?!(?:you|user|username)\/)[A-Za-z0-9._-]+\//g,
  },
  // Prefix, underscore, then an opaque mixed-case token: an all-caps constant
  // name is not one.
  {
    kind: "github-node-id",
    pattern:
      /\b(?:PVT[A-Z]*|I|PR|R|U|O)_(?=[A-Za-z0-9-]*[a-z])(?=[A-Za-z0-9-]*[A-Z0-9])[A-Za-z0-9-]{10,}/g,
  },
  {
    kind: "email",
    pattern: /\b[A-Za-z0-9._%+-]+@(?!example\.)[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/g,
  },
  // A four-digit issue or pull request number points at one private tracker.
  { kind: "issue-number", pattern: /(?<![\w&])#\d{4,}(?![\w%;])/g },
];

// Every tracked file is scanned, whatever its name: an extension allow-list
// would let a private value through in the first file type it forgot.
export function isText(buffer) {
  return !buffer.includes(0);
}

export function findLeaks(text) {
  const leaks = [];
  for (const [index, line] of text.split(/\r?\n/).entries()) {
    for (const { kind, pattern } of LEAK_PATTERNS) {
      for (const match of line.matchAll(pattern)) {
        leaks.push({ line: index + 1, kind, match: match[0] });
      }
    }
  }
  return leaks;
}

export async function checkLock({ root, lock, files }) {
  const errors = [];
  const locked = new Map(lock.entries.map((entry) => [entry.target, entry]));
  for (const entry of lock.entries) {
    if (!LOCK_STATES.has(entry.state)) {
      errors.push(
        `${entry.target}: unknown state "${entry.state}" in PROVENANCE.json.`,
      );
      continue;
    }
    if (entry.state !== "generated") continue;
    const content = await readFile(path.join(root, entry.target)).catch(
      () => null,
    );
    if (content === null) {
      errors.push(`${entry.target}: listed in PROVENANCE.json but missing.`);
      continue;
    }
    const hash = createHash("sha256").update(content).digest("hex");
    if (hash !== entry.outputHash) {
      errors.push(
        `${entry.target}: content differs from PROVENANCE.json. Generated files are regenerated from their source, never edited here.`,
      );
    }
  }
  for (const file of files) {
    if (SELF.has(file) || locked.has(file)) continue;
    const content = await readFile(path.join(root, file), "utf8");
    if (content.includes(GENERATED_MARKER)) {
      errors.push(
        `${file}: carries the generated-file marker but is absent from PROVENANCE.json.`,
      );
    }
  }
  return errors;
}

async function main() {
  const root = process.cwd();
  const { stdout } = await execFileAsync("git", ["ls-files", "-z"], {
    cwd: root,
  });
  const files = [];
  for (const file of stdout.split("\0").filter(Boolean)) {
    if (isText(await readFile(path.join(root, file)))) files.push(file);
  }
  const lock = JSON.parse(
    await readFile(path.join(root, "PROVENANCE.json"), "utf8"),
  );
  const errors = await checkLock({ root, lock, files });
  for (const file of files) {
    if (SELF.has(file)) continue;
    const content = await readFile(path.join(root, file), "utf8");
    for (const leak of findLeaks(content)) {
      errors.push(`${file}:${leak.line}: ${leak.kind} "${leak.match}".`);
    }
  }
  if (errors.length > 0) {
    for (const error of errors) process.stderr.write(`- ${error}\n`);
    process.exitCode = 1;
    return;
  }
  process.stdout.write(
    `Check passed (${files.length} files, ${lock.entries.length} generated).\n`,
  );
}

const isMain =
  process.argv[1] &&
  pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url;
if (isMain) {
  main().catch((error) => {
    process.stderr.write(
      `${error instanceof Error ? error.message : String(error)}\n`,
    );
    process.exitCode = 1;
  });
}

#!/usr/bin/env bun

import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";

type JsonRecord = Record<string, unknown>;

function parseArgs(args: string[]): { input: string; output: string } {
  const values = new Map<string, string>();

  for (let index = 0; index < args.length; index += 2) {
    const key = args[index];
    const value = args[index + 1];

    if (!key?.startsWith("--") || !value) {
      throw new Error("Usage: render-handoff.ts --input <report.json> --output <report.html>");
    }

    values.set(key, value);
  }

  const input = values.get("--input");
  const output = values.get("--output");

  if (!input || !output) {
    throw new Error("Both --input and --output are required.");
  }

  return { input: resolve(input), output: resolve(output) };
}

function assertArray(data: JsonRecord, key: string): void {
  if (!Array.isArray(data[key])) {
    throw new Error(`Expected "${key}" to be an array.`);
  }
}

function validate(data: unknown): asserts data is JsonRecord {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throw new Error("Handoff input must be a JSON object.");
  }

  const record = data as JsonRecord;
  const requiredStrings = ["title", "subtitle", "status", "summary", "goal"];

  for (const key of requiredStrings) {
    if (typeof record[key] !== "string" || record[key] === "") {
      throw new Error(`Expected a non-empty string at "${key}".`);
    }
  }

  for (const key of ["sections", "verification", "usage"]) {
    assertArray(record, key);
  }
}

function safeJson(data: JsonRecord): string {
  return JSON.stringify(data)
    .replaceAll("<", "\\u003c")
    .replaceAll(">", "\\u003e")
    .replaceAll("&", "\\u0026")
    .replaceAll("\u2028", "\\u2028")
    .replaceAll("\u2029", "\\u2029");
}

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (character) => {
    const entities: Record<string, string> = {
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#039;",
    };

    return entities[character];
  });
}

async function main(): Promise<void> {
  const { input, output } = parseArgs(Bun.argv.slice(2));
  const templatePath = resolve(import.meta.dir, "../templates/handoff.html");
  const [rawInput, template] = await Promise.all([
    readFile(input, "utf8"),
    readFile(templatePath, "utf8"),
  ]);
  const data: unknown = JSON.parse(rawInput);

  validate(data);

  const normalizedData = {
    ...data,
    generatedAt:
      typeof data.generatedAt === "string"
        ? data.generatedAt
        : new Date().toISOString(),
  };
  const html = template
    .replace(
      "__DOCUMENT_TITLE__",
      escapeHtml(`${String(data.title)} — Build handoff`),
    )
    .replace("__HANDOFF_DATA__", safeJson(normalizedData));

  await mkdir(dirname(output), { recursive: true });
  await writeFile(output, html, "utf8");
  console.log(output);
}

await main();

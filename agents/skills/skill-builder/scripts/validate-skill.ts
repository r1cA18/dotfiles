import { existsSync, readFileSync, statSync } from "node:fs";
import { basename, resolve } from "node:path";

const directory = process.argv[2];
if (!directory || process.argv.length !== 3) {
  console.error("Usage: validate-skill.sh <skill-directory>");
  process.exit(2);
}

const errors: string[] = [];
const warnings: string[] = [];
try {
  const file = resolve(directory, "SKILL.md");
  const content = readFileSync(file, "utf8").replace(/\r\n/g, "\n");
  const match = content.match(/^---\n([\s\S]*?)\n---(?:\n|$)/);
  if (!match) {
    errors.push("Missing opening or closing frontmatter delimiter");
  } else {
    let metadata: unknown;
    try {
      metadata = Bun.YAML.parse(match[1]);
    } catch (error) {
      errors.push(`Invalid YAML: ${error instanceof Error ? error.message : error}`);
    }
    if (metadata && typeof metadata === "object" && !Array.isArray(metadata)) {
      const { name, description } = metadata as Record<string, unknown>;
      if (typeof name !== "string" || !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(name) || name.length > 64) {
        errors.push("name must be a kebab-case string of at most 64 characters");
      } else if (name !== basename(resolve(directory))) {
        warnings.push(`name (${name}) differs from directory; verify distribution ID mapping`);
      }
      if (typeof description !== "string" || !description.trim()) {
        errors.push("description must be a non-empty string");
      } else if (description.length > 1024) {
        errors.push("description exceeds the portable 1024-character limit");
      }
    } else if (metadata !== undefined) {
      errors.push("Frontmatter must be a YAML mapping");
    } else if (!errors.length) {
      errors.push("Frontmatter must contain name and description");
    }

    // Check ordinary inline local links. Fenced examples and URLs are not files.
    const body = content.slice(match[0].length)
      .replace(/^(`{3,}|~{3,}).*\n[\s\S]*?^\1[^\n]*$/gm, "")
      .replace(/(`+)[\s\S]*?\1/g, "");
    for (const link of body.matchAll(/\[[^\]\n]*\]\((?:<([^>\n]+)>|([^\s)]+))(?:\s+"[^"\n]*")?\)/g)) {
      const target = link[1] ?? link[2];
      if (/^(?:[a-z][a-z\d+.-]*:|\/|#)/i.test(target)) continue;
      const path = decodeURIComponent(target.split(/[?#]/)[0]);
      if (path && (!existsSync(resolve(directory, path)) || !statSync(resolve(directory, path)).isFile())) {
        errors.push(`Referenced file not found: ${path}`);
      }
    }
  }
} catch (error) {
  errors.push(error instanceof Error ? error.message : String(error));
}

for (const error of errors) console.error(`ERROR: ${error}`);
for (const warning of warnings) console.log(`WARN: ${warning}`);
console.log(`Result: ${errors.length} error(s), ${warnings.length} warning(s)`);
process.exit(errors.length ? 1 : 0);

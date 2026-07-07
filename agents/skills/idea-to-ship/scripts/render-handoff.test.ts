import { afterEach, describe, expect, test } from "bun:test";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const temporaryDirectories: string[] = [];
const script = resolve(import.meta.dir, "render-handoff.ts");

afterEach(async () => {
  await Promise.all(
    temporaryDirectories.splice(0).map((directory) =>
      rm(directory, { force: true, recursive: true }),
    ),
  );
});

async function fixture(data: unknown): Promise<{ input: string; output: string }> {
  const directory = await mkdtemp(join(tmpdir(), "idea-to-ship-"));
  temporaryDirectories.push(directory);
  const input = join(directory, "handoff.json");
  const output = join(directory, "handoff.html");
  await writeFile(input, JSON.stringify(data), "utf8");
  return { input, output };
}

describe("render-handoff", () => {
  test("renders a self-contained handoff and escapes script-closing input", async () => {
    const { input, output } = await fixture({
      title: "Example </script>",
      subtitle: "A shipped result",
      status: "shipped",
      summary: "Summary",
      goal: "Goal",
      sections: [],
      verification: [],
      usage: [],
    });

    const process = Bun.spawn(
      ["bun", script, "--input", input, "--output", output],
      { stderr: "pipe", stdout: "pipe" },
    );

    expect(await process.exited).toBe(0);
    const html = await readFile(output, "utf8");
    expect(html).toContain("<title>Example &lt;/script&gt; — Build handoff</title>");
    expect(html).toContain("Example \\u003c/script\\u003e");
    expect(html).toContain('"generatedAt":');
    expect(html).not.toContain("__HANDOFF_DATA__");
  });

  test("rejects an incomplete handoff", async () => {
    const { input, output } = await fixture({ title: "Incomplete" });
    const process = Bun.spawn(
      ["bun", script, "--input", input, "--output", output],
      { stderr: "pipe", stdout: "pipe" },
    );

    expect(await process.exited).not.toBe(0);
    expect(await new Response(process.stderr).text()).toContain(
      'Expected a non-empty string at "subtitle".',
    );
  });
});

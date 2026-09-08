import { expect, test } from "bun:test";
import { fileURLToPath } from "node:url";

const filter = fileURLToPath(new URL("messages.jq", import.meta.url));

function extract(records: unknown[]) {
  const result = Bun.spawnSync(["jq", "-c", "-f", filter], {
    stdin: Buffer.from(records.map((record) => JSON.stringify(record)).join("\n")),
  });
  expect(result.exitCode).toBe(0);
  return result.stdout.toString().trim().split("\n").filter(Boolean).map(JSON.parse);
}

test("Codex preserves message order while omitting privileged and encrypted content", () => {
  const message = (role: string, content: unknown[]) => ({
    type: "response_item", payload: { type: "message", role, content },
  });
  expect(extract([
    { type: "session_meta", payload: { cwd: "/example" } },
    message("developer", [{ type: "input_text", text: "private instructions" }]),
    message("user", [{ type: "input_text", text: "Continue the workspace task" }]),
    { type: "response_item", payload: { type: "function_call_output", output: "tool result" } },
    message("assistant", [
      { type: "output_text", text: "The search check passed" },
      { type: "encrypted_content", encrypted_content: "opaque" },
      { type: "output_text", text: "The runtime check remains" },
    ]),
  ])).toEqual([
    { role: "user", text: "Continue the workspace task" },
    { role: "assistant", text: "The search check passed\nThe runtime check remains" },
  ]);
});

test("Claude supports string and block content without replaying tool results", () => {
  expect(extract([
    { type: "user", message: { role: "user", content: "Resume the task" } },
    { type: "assistant", message: { role: "assistant", content: [
      { type: "thinking", thinking: "private reasoning" },
      { type: "tool_use", name: "Bash", input: { command: "false" } },
      { type: "text", text: "I need to verify the build" },
    ] } },
    { type: "user", message: { role: "user", content: [
      { type: "tool_result", content: "not conversation text" },
    ] } },
  ])).toEqual([
    { role: "user", text: "Resume the task" },
    { role: "assistant", text: "I need to verify the build" },
  ]);
});

test("event mirrors and incomplete content do not create duplicate messages", () => {
  expect(extract([
    { type: "event_msg", payload: { type: "agent_message", message: "mirror" } },
    { type: "response_item", payload: { type: "message", role: "assistant", content: null } },
    { type: "user", message: null },
  ])).toEqual([]);
});

test("malformed JSON is reported instead of silently discarded", () => {
  const result = Bun.spawnSync(["jq", "-c", "-f", filter], {
    stdin: Buffer.from('{"type":'),
  });
  expect(result.exitCode).not.toBe(0);
});

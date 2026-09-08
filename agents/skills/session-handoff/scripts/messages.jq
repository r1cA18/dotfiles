# Extract conversation text without tool, reasoning, or encrypted payloads.
def plaintext:
  if type == "string" then .
  elif type == "array" then
    map(select(.type == "text" or .type == "input_text" or .type == "output_text")
      | .text | select(type == "string")) | join("\n")
  else ""
  end;

if .type == "response_item" and .payload.type == "message" then
  .payload
elif (.type == "user" or .type == "assistant") and (.message | type) == "object" then
  .message
else empty
end
| select(.role == "user" or .role == "assistant")
| {role, text: (.content | plaintext)}
| select(.text != "")

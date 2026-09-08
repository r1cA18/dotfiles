# Tool Preferences

## Commands The Owner Must Run

- When the owner must run a command manually, copy the exact command to their local clipboard and show the same text in the response
- On macOS use `pbcopy`; on Ubuntu/Linux with an accessible desktop session use `wl-copy` for Wayland or `xclip -selection clipboard` / `xsel --clipboard --input` for X11 when available
- Pass the command as literal text through stdin without executing it or expanding substitutions; omit prompts, Markdown fences, and the trailing newline
- Copy only the next required command or an explicitly intended command block, not every alternative; state what was copied only after the clipboard command succeeds
- Do not read the existing clipboard or copy credentials; use environment variable references or placeholders for secrets
- If clipboard access is unavailable or fails (including headless SSH), show the command and report that it was not copied; do not assume a remote clipboard is the owner's local clipboard
- Do not install clipboard tools globally or enable forwarding merely to copy a command; manage persistent dependencies through Nix if needed

## Web Search and Page Retrieval

Use the product's built-in Web tools by default for Web search and page
content retrieval. Depending on the agent these may be named `Web`,
`WebSearch`, `WebFetch`, or similar.

Do not invoke `agent-browser` merely to search the Web, open a URL, or read
page content that the built-in Web tools can retrieve.

Use `agent-browser` only when the task requires an actual browser UI, such as:

- checking visual layout or rendered UI
- taking a screenshot
- clicking, typing, scrolling, or submitting a form
- using a logged-in browser session
- interacting with a dynamic page that built-in Web retrieval cannot handle

If built-in Web retrieval fails because the page requires browser interaction,
then switch to `agent-browser` and state why.

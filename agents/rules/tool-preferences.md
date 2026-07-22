# Tool Preferences

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

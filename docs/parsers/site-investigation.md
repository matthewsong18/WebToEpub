# Site investigation

`just build` is the validation command. Use browser tooling for investigation
when the user requests it or the task needs site information unavailable from
existing sources. Follow [CONTRIBUTING.md](../../CONTRIBUTING.md) when reporting
what was verified.

Some sites, including Lunarx, detect DevTools connections. Chrome DevTools MCP
uses the DevTools Protocol even when the visible DevTools panel is closed.
A page that blanks or redirects under that connection may differ from the user's
normal browser session. Stop repeating that inspection route once this behavior
is established for the site.

Prefer user-supplied page source, saved JavaScript bundles, sanitized network
captures, public API responses, and the user's manual observations. Inspect saved
scripts as text. Preserve the distinction between the initial HTML, the rendered
DOM, and later API responses when identifying where chapter content originates.
Protect credentials and cookies when inspecting captures.

For ordinary browser connection setup and profile conflicts, consult
[the DevTools setup guide](../chrome-devtools-setup.md). That guide is optional
investigation tooling, not a parser completion checklist.

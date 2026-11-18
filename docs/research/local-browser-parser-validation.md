# Local browser validation for WebToEpub parsers

> Historical proposal, superseded by the build-only workflow in
> [CONTRIBUTING.md](../../CONTRIBUTING.md). The browser runner, live validation,
> and monitoring steps below are not implementation requirements.

For the subsequent devenv launcher and connection instructions, see the
[Chrome DevTools setup guide](../chrome-devtools-setup.md). The availability
observations below describe the original research session.

Researched 2026-11-08. This is a tooling recommendation and implementation proposal, not a completed browser integration. Official documentation and local source were inspected; no browser tooling was installed and no live parser run was performed.

Current session availability: the browser-tool inventory exposed only the in-app browser and MCP Apps, with no host Chromium browser connected. PATH checks found Firefox, Node, Podman and Nix, but no Chrome/Chromium executable; no Playwright browser cache was detected. These checks do not prove that Chromium is absent system-wide. They explain why the recommendation has not been demonstrated end to end in this session. The first setup step must establish and verify that connection. These are local environment observations, not upstream-tool limitations.

## Recommendation

Give agents a dedicated, persistent, local browser with the actual WebToEpub extension loaded. Use **Chrome DevTools MCP with its extension tools enabled** for interactive investigation and validation after edits. Add a small **Playwright library runner** for repeatable checks of a few live sites and eventual scheduled monitoring.

These solve different needs: browser access lets an agent investigate and reproduce failures; explicit checks and repeated runs detect regressions. A browser connection alone does not detect future site changes. Even a monitor only covers its sampled pages and behaviors.

Start with two or three representative sites: straightforward HTML, an API-backed parser, and a rendered-tab parser such as Fenrir. Expand coverage after the workflow produces useful evidence. Do not begin by crawling every supported site.

## Why this repository needs the extension environment

The extension's HTTP client has cookie handling and declarative network-rule support. Fenrir's rendered capture uses browser scripting APIs, including a Firefox MV2 fallback. Running selectors in Node or fetching pages with curl does not exercise these behaviors. Sources: [HttpClient.js](../../plugin/js/HttpClient.js), [FenrirealmParser.js](../../plugin/js/parsers/FenrirealmParser.js).

The normal chapter lifecycle includes throttling, `fetchChapter`, preprocessing, content discovery, image processing, and later `convertRawDomToContent` cleanup. A selector returning an element is therefore insufficient evidence that the resulting chapter is correct. Sources: [Parser.js](../../plugin/js/Parser.js), especially `fetchWebPageContent` and `convertRawDomToContent`.

The source manifest is MV3, but packaging converts Firefox to MV2 and rewrites permissions and the action declaration. Packaging also modifies the Chromium manifest. Prefer extracting the current build's appropriate archive to a temporary directory and loading that directory when validating release behavior. Source-directory loading can be useful during development, but record that it differs from the packaged artifact. Sources: [manifest.json](../../plugin/manifest.json), [pack.js](../../eslint/pack.js).

There is **no background service worker declared in this extension's source manifest**. Do not copy Playwright's example that waits for a service-worker event to discover the extension ID: it could wait indefinitely here. Obtain the ID from the DevTools extension tools, or implement an explicit alternative discovery mechanism in the scripted runner. Source: [manifest.json](../../plugin/manifest.json).

The normal action opens the conversion UI in a tab and passes the source tab ID as `popup.html?id=<tab ID>`. Opening bare `popup.html` is not an equivalent initialization path. The UI exposes the selected parser through `spanParserName`, and `main.getCurrentParser()` can assist diagnosis inside the extension page. Sources: [main.js](../../plugin/js/main.js), [ChapterUrlsUI.js](../../plugin/js/ChapterUrlsUI.js), [popup.html](../../plugin/popup.html).

The current agent instructions prohibit new parser unit tests and fixtures. Live extension checks can fit that constraint without creating files in `unitTest/` or `testdata/`. `just build` packages and lints; the existing `test` npm command starts an HTTP server. Sources: [AGENTS.md](../../AGENTS.md), [justfile](../../justfile), [package.json](../../package.json).

## Options

| Option | Verified capability | Fit here |
| --- | --- | --- |
| Chrome DevTools MCP | Local browser control with explicit unpacked-extension lifecycle tools | Best first interactive setup; inspect actual requests, console errors and extension output |
| Playwright library | Persistent Chromium contexts can load extensions; supports programmatic browser and download control | Best repeatable local checks and scheduled runs |
| Playwright MCP | Agent browser interaction, persistent profiles, and an extension bridge to existing Chromium sessions | Good alternative when already available; requires a separate extension-loading plan |
| Firefox `web-ext` | Starts Firefox with a temporary extension and reloads edited source | Useful Firefox lane; not by itself an agent browser-control or assertion framework |

Capabilities in this table come from [Chrome extension agent documentation](https://developer.chrome.com/docs/devtools/agents/extensions), [Playwright extension documentation](https://playwright.dev/docs/chrome-extensions), [Playwright MCP](https://github.com/microsoft/playwright-mcp), and [Mozilla web-ext documentation](https://extensionworkshop.com/documentation/develop/getting-started-with-web-ext/). The suitability judgments are this research's recommendations.

### Chrome DevTools MCP: first choice for interactive work

Google documents `install_extension`, `list_extensions`, `reload_extension`, and `trigger_extension_action`. Enable the otherwise-disabled extension category with `--categoryExtensions`. Installation requires an absolute unpacked-directory path allowed by the MCP server's filesystem roots. This directly supports loading an edited local extension, reloading it, and invoking its action on a live site. Source: [Google's extension workflow](https://developer.chrome.com/docs/devtools/agents/extensions).

The server exposes page evaluation, console inspection, network inspection, snapshots, and screenshots. Its tool reference also documents service-worker evaluation, although this extension does not currently have such a worker. Source: [tool reference](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/tool-reference.md).

Proposed server arguments, not installed configuration:

```text
npx -y chrome-devtools-mcp@latest
  --categoryExtensions
  --userDataDir=/home/lux/.cache/webtoepub-agent-browser
  --filesystemRoot=/home/lux/projects/WebToEpub
  --filesystemRoot=/tmp
  --no-usage-statistics
  --no-performance-crux
```

Use a real argument array when configuring the MCP client; the line breaks above are only for readability. Replace `@latest` with a recorded version once the first working setup is established. Profile, filesystem-root, optional executable-path, and telemetry switches are documented in the [server configuration reference](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/configuration.md). The server requires Node LTS, npm, and current Chrome or newer according to its [README](https://github.com/ChromeDevTools/chrome-devtools-mcp).

Prefer a browser launched by the server initially. An alternative is attaching with `--browser-url=http://127.0.0.1:9222` to a separately launched dedicated browser. Chrome requires a non-default profile for remote-debugging switches from Chrome 136 onward. Sources: [DevTools MCP connection instructions](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/advanced-usage.md), [Chrome remote-debugging change](https://developer.chrome.com/blog/remote-debugging-port).

Use a dedicated profile so website sessions can persist without coupling validation to daily browsing. Assign one profile owner at a time; use distinct profiles for concurrent browser instances. Validate extension installation and popup/action discovery against the chosen browser/server versions before treating this route as proven for WebToEpub.

### Playwright: repeatable live checks

The official extension guide supports Chromium extensions through persistent contexts with `--disable-extensions-except` and `--load-extension`. It recommends bundled Chromium because branded Chrome/Edge removed command-line sideload flags. Full Chromium via `channel: "chromium"` supports headless extensions; headed mode is also supported. These are Playwright launch-path facts, not a claim that DevTools MCP's extension-install API is unavailable in branded Chrome. Source: [Playwright extension guide](https://playwright.dev/docs/chrome-extensions).

Proposed runner launch shape:

```javascript
const context = await chromium.launchPersistentContext(profileDirectory, {
    channel: "chromium",
    headless: false,
    acceptDownloads: true,
    args: [
        `--disable-extensions-except=${unpackedExtensionDirectory}`,
        `--load-extension=${unpackedExtensionDirectory}`
    ]
});
```

This is a launch sketch, not a complete WebToEpub runner. It still needs extension-ID discovery without a service worker, correct source-tab/action initialization, bounded waits, checks and artifact collection. Begin headed so authentication and challenges are observable. Enable headless operation only after comparison against a successful headed run.

Playwright MCP supplies persistent profiles and can connect to existing browser sessions through its own Chromium extension bridge. The bridge is separate from WebToEpub. Its official documentation does not make the generic default session an automatic loader for this repository's extension. Sources: [Playwright MCP README](https://github.com/microsoft/playwright-mcp), [browser connection documentation](https://playwright.dev/mcp/configuration/browser-extension).

For evidence capture, Playwright library tracing can record browser operations and network activity; it does not automatically record arbitrary assertion results outside Playwright Test. Write the runner's check results to a separate report. Source: [Tracing API](https://playwright.dev/docs/api/class-tracing).

### Firefox remains a separate validation lane

Mozilla's `web-ext run` temporarily loads an extension into Firefox, watches files and reloads changes. Custom profiles are supported; preserving changes requires an additional option. Source: [Mozilla web-ext guide](https://extensionworkshop.com/documentation/develop/getting-started-with-web-ext/).

Use the packaged Firefox variant when checking Firefox-specific behavior. Chromium success cannot establish correctness of MV2 APIs or Firefox cookie and scripting behavior. Playwright's documented extension-loading recipe is Chromium-only; do not present Playwright Firefox navigation support as Firefox extension testing support. Sources: [pack.js](../../eslint/pack.js), [Playwright extension guide](https://playwright.dev/docs/chrome-extensions).

## Proposed validation contract

The following is a proposed design, not existing functionality.

For each supported live scenario, keep a small descriptor: parser identity, a stable book URL, representative free chapter URLs, expected title/author where stable, and a few content expectations verified against the actual site. These are live-check configuration, not saved HTML fixtures. Avoid exact total chapter counts for ongoing books and exact full-text snapshots.

After changing a parser, run the same bounded workflow before and after the edit:

1. Build, identify the exact source revision and artifact, load/reload that artifact, and navigate to the target book.
2. Invoke the extension action. Verify the intended parser is selected rather than a generic fallback. Wait for TOC completion, not an arbitrary sleep.
3. Check metadata, unique valid chapter links, ordering across a volume/pagination boundary, and default exclusion of observed locked/unreleased chapters.
4. Select only a small known-free sample. Record/reset the monitoring profile's extension preferences so reading-list history cannot silently deselect the sample. Keep the parser's normal throttle and disable skip-failed-chapter behavior for this run; inspect per-chapter errors regardless. Retain a strict overall timeout.
5. Inspect the resulting EPUB: expected chapter count and order, valid chapter XHTML, title plus actual prose, absence of navigation/challenge/lock text, and required images when relevant. Use site-specific evidence for content thresholds; short chapters and illustrated chapters need different checks.
6. Save a compact result containing revision/artifact, tool/browser version, scenario URLs, checks, error class, and diagnostic artifact paths. Inspect the EPUB or chapter preview visually for the first successful scenario and after meaningful content-cleanup changes.

An agent can perform this interactively first. Automate the repeated portion only after a successful real run establishes the correct workflow. Do not replace WebToEpub's HTTP calls or browser APIs with mocks: the integration is what needs validation.

Preference handling matters: the parser consults the reading list and can retain a chapter error when `skipChaptersThatFailFetch` is enabled. A successful file download alone must not count as a pass; assert that every requested sample chapter is present and error-free. Sources: [Parser.js](../../plugin/js/Parser.js), [UserPreferences.js](../../plugin/js/UserPreferences.js).

For tricky failures, evaluate the real parser in its initialized extension page and inspect its intermediate output, but still complete a normal user-flow run. Calling a hook directly can miss preference initialization, throttling, image collection, cleanup or packaging.

## Detecting future site changes

Run the same scenarios periodically against live sites and against changed parsers before review. A local systemd timer or another local scheduler can invoke the deterministic runner; scheduling is a later implementation choice, not configured by this research. The machine must be awake and able to reach the sites. Browser control and a scheduler are both necessary for unattended monitoring.

Use structured outcomes:

- **PASS:** the sampled live contract passed.
- **PARSER_FAILURE:** valid expected site content was reached but extraction, ordering or EPUB checks failed.
- **BLOCKED:** challenge, authentication, lock state or rate limiting prevented validation.
- **UNAVAILABLE:** DNS, connection or server failure.
- **INCONCLUSIVE:** timeout or ambiguous evidence that requires investigation.

Cloudflare documents `cf-mitigated: challenge` on Challenge Page responses; this can support classification where headers are observable. It does not detect every embedded Turnstile or site-specific lock state. Source: [Cloudflare challenge-response documentation](https://developers.cloudflare.com/cloudflare-challenges/challenge-types/challenge-pages/detect-response/).

Record every unsuccessful check, but distinguish an initial failure from a persistent change. Recheck once after an appropriate backoff, stop repeated requests on challenges/429s, and surface transitions such as pass-to-failure or blocked-needs-human. A failure with unchanged parser code is evidence of an external change, not proof: session expiry, account state, geography, browser updates and outages are alternative explanations. Show the evidence before declaring a parser broken.

Keep compact numeric/link metadata baselines and short expected anchors rather than copyrighted full chapters. Ignore routine growth in chapter counts. Flag suspicious drops, missing previously verified links, empty output or major content-length changes for review. For ambiguous cases, replay a previously known-good revision against the same current site and profile; never automatically alter selectors or overwrite a baseline just to restore green results.

Retain screenshots, network status summaries, error stacks and the small output EPUB locally on failure. Redact credentials/cookies and avoid committing profiles or raw response bodies. Respect the parser's request interval and keep per-site chapter concurrency at one. Source for repository throttle requirements: [AGENTS.md](../../AGENTS.md).

This approach can detect sampled breakage after site changes without new parser unit tests. It cannot guarantee all books, account tiers, locales, pagination branches or future site layouts; each extra coverage claim needs a representative scenario.

## First implementation milestone

1. Establish a dedicated host browser connection with extension lifecycle control.
2. Demonstrate one complete live book-to-small-EPUB run and save the evidence.
3. Repeat after editing/reloading the parser to prove the latest code is running.
4. Build a small deterministic runner for two or three scenarios, including a deliberate failing content check to demonstrate detection.
5. Add periodic execution and quiet-on-success reporting only after the local checks are reliable.

No dependencies, extension manifests, permissions, agent configuration or scheduler entries were changed for this research.

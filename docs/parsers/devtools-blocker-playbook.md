# Investigating pages that block DevTools

Research date: 2026-11-17. This is a proposed investigation workflow based on
primary documentation and source review. No bypass was tried against live
Lunarx during this research. Browser versions and site bundles can change the
outcome. See the [library research](devtools-blocker-research.md) for detector
implementations and library-specific switches.

## Recommendation for WebToEpub

Use two routes: obtain parser evidence without attaching a debugger when that
is sufficient; restore interactive DevTools by preventing the identified
detector from starting when debugging is necessary. Prefer a precise change to
the detector's initialization over broad changes to timers, logging, or browser
built-ins. This ranking is an engineering recommendation, not a measured
comparison of success rates.

The existing [Lunarx parser](../../plugin/js/parsers/LunarxParser.js) already
illustrates the first route: API metadata plus a content snapshot through an
extension-injected function. This establishes the architecture in this checkout,
not present-day website availability or successful chapter downloading.

| Priority | Technique | Best fit | Main limit |
| --- | --- | --- | --- |
| 1 | Saved HTML/bundles and ordinary extension DOM capture | Finding selectors, metadata, content origin | Does not provide breakpoints or historical network bodies |
| 2 | Undock DevTools; suppress a known debugger pause | A simple viewport check or repeated pauses | Does not stop other detectors or their redirect handlers |
| 3 | Block a standalone detector or patch its initialization | Known detector URL or bundled startup call | Must preserve application dependencies |
| 4 | Capture/replace responses through a local proxy | Detector fires before DevTools can be configured; need network bodies | Requires proxy routing and trusted local CA for HTTPS |
| 5 | Targeted early extension/userscript hook | Exact detector behavior identified in source | Execution world, timing, captured references, frames |
| 6 | Patched automation library or browser | A diagnosed instrumentation side channel | Tool compatibility and ongoing maintenance |

The library report explains the first two detector classes; the official
[Chrome blocking](https://developer.chrome.com/docs/devtools/request-conditions),
[override](https://developer.chrome.com/docs/devtools/overrides),
[extension](https://developer.chrome.com/docs/extensions/develop/concepts/content-scripts),
and [proxy](https://docs.mitmproxy.org/stable/overview/features/) documentation
supports the mechanisms in this comparison. Their suitability for this repo is
our inference.

## 1. Preserve the evidence before changing execution

Start from the normal browsing state described in [site investigation](site-investigation.md).
Keep initial response HTML, later rendered DOM, and API response bodies separate.
Search saved JavaScript as text for detector names and distinctive operations:
`DisableDevtool`, `devtools-detector`, `debugger`, `outerWidth`, `innerWidth`,
`Object.defineProperty`, `console.clear`, `sourceMappingURL`, and redirect code.
A matching word is a lead; confirm the initialization, handler, and version.

For a chapter whose text is already rendered, an extension can read the shared
DOM from its isolated world without attaching through `chrome.debugger`.
The page's JavaScript globals remain separate. This is a way to obtain evidence,
not a promise that extension activity is invisible. Chrome documents both the
[DOM access and world isolation](https://developer.chrome.com/docs/extensions/develop/concepts/content-scripts).

Record the exact bundle URL and a hash of the saved original. A source package
name alone does not establish which options the site enabled. We have not
recovered the previously identified Lunarx repository from this checkout;
`theajack/disable-devtool` remains a candidate here.

## 2. Address a specific symptom

### Repeated pauses on `debugger`

In Chrome Sources, use **Never pause here** on the offending statement. It is a
conditional breakpoint with a false condition. Chrome warns that multiple
statements on one line and source mapping can make the location ambiguous.
This suppresses a pause; the surrounding detector code still executes.
See [Chrome's breakpoint reference](https://developer.chrome.com/docs/devtools/javascript/breakpoints).

For tooling that actually exposes raw protocol commands,
`Debugger.setSkipAllPauses({skip: true})` suppresses pauses broadly. This also
prevents useful debugging pauses. It does not hide inspection side effects or
remove a redirect. It is a protocol operation, not JavaScript to paste into the
page console. See the [Debugger protocol](https://chromedevtools.github.io/devtools-protocol/tot/Debugger/#method-setSkipAllPauses).

### Page blanks, navigates away, or repeatedly clears the console

Find the detector's call site and consequence. Stop initialization before it
executes, or narrowly replace that consequence. Suspending after a redirect has
already run is too late. For implementation details and exported suspension
controls, follow the [library report](devtools-blocker-research.md).

The open-source [Anti-Anti-Debug](https://github.com/Andrews54757/Anti-Anti-Debug)
extension documents console filtering, debugger-function removal, and periodic
checks. Its author warns that the changes can break sites. It is a candidate
for a disposable investigation profile after reviewing its source and manifest;
current Chromium installation compatibility was not established here.

### DevTools itself causes additional requests

Disable JavaScript source maps before navigation if source-map requests are the
identified signal. Chrome documents the setting under Settings > Preferences >
Sources. This removes a particular request path, not every inspection signal.
See [Chrome source maps](https://developer.chrome.com/docs/devtools/javascript/source-maps).

Undocking can address dimension-based detectors. It cannot address console
serialization or timing detectors. The
[devtools-detect author](https://github.com/sindresorhus/devtools-detect)
explicitly describes flaws and browser-dependent false positives; infer neither
a universal detector nor a universal undocking fix.

## 3. Stop the detector before startup

### Separate script

Configure an exact URL block before loading the affected page. Chrome's Request
conditions drawer supports URL patterns, but blocking stops when DevTools closes.
An extension rule is a different option that need not attach a debugger.
Avoid blocking a whole application bundle simply because it contains detector
code. See [Request conditions](https://developer.chrome.com/docs/devtools/request-conditions).

Chromium MV3's
[declarativeNetRequest](https://developer.chrome.com/docs/extensions/reference/api/declarativeNetRequest)
can block or redirect requests; it is not a general response-body editor.
Most MV3 extensions cannot use blocking `webRequest` listeners, though ordinary
observation remains available. See [webRequest](https://developer.chrome.com/docs/extensions/reference/api/webRequest).
Do not assume an observation API returns response bodies.

### Detector bundled into the application

Save the original bundle. In a local copy, remove only its detector startup call
or replace that call with an expression preserving the caller's expected value.
Keep module exports and application startup intact. Review the exact code rather
than performing a global textual replacement of `debugger`.

Chrome's Network > **Override content** saves a response locally and serves the
edited copy on reload. Configure this from a neutral page if the target becomes
unusable immediately. Overrides disable cache and do not persist arbitrary
Elements-panel DOM edits. See [Local overrides](https://developer.chrome.com/docs/devtools/overrides).

For integrity-protected scripts, changing bytes may invalidate the resource;
check the importing HTML and any integrity metadata before attributing a failed
load to the detector. See [Subresource Integrity](https://developer.mozilla.org/en-US/docs/Web/Security/Subresource_Integrity).
Service-worker responses and hashed URLs also require identifying the resource
actually used by the page.

### Early hooks

A page-global patch must run in the page's MAIN world before the detector captures
the original function. An ordinary isolated-world patch to `window.console`
does not patch the page's console. For a Chromium helper extension, narrowly
scope the host and use a predeclared `document_start` content script with the
appropriate world. See [content-script timing and worlds](https://developer.chrome.com/docs/extensions/develop/concepts/content-scripts).

For a userscript, verify the manager's execution world and startup timing;
`document-start` is not sufficient evidence that it beat every inline script.
Consult [Tampermonkey's run-at and sandbox documentation](https://www.tampermonkey.net/documentation.php).
Prefer a detector-specific hook to disabling all timers or all console methods.

For a browser supporting full uBlock Origin, a site-specific scriptlet can be
lighter than writing a helper extension. Its `prevent-setInterval` can match a
callback's text and delay; `noeval-if` matches evaluated payloads. For example,
the following illustrative filter suppresses interval callbacks containing
`debugger` on a placeholder host:

```text
example.com##+js(nosiif, debugger)
```

This misses callbacks without that literal text and does not remove inline
statements or cover every dynamic code-generation path. Match the saved source,
then scope narrowly. See the [scriptlet library](https://github.com/gorhill/uBlock/wiki/Resources-Library)
and [hostname-specific syntax](https://github.com/gorhill/uBlock/wiki/Static-filter-syntax#scriptlet-injection).
These are full-uBO capabilities; do not assume that an MV3 blocker, including
uBlock Origin Lite, exposes the same custom scriptlet interface.

The connected project browser tool currently advertises a `navigate_page`
`initScript` parameter, executed before other scripts on the next navigation.
That is a tool-schema observation, not a live execution check. It offers an early
hook, but the browser still has its DevTools connection. Patching from
`evaluate_script` after loading the page may already be too late.

## 4. Capture or replace traffic without DevTools

Mitmproxy can record traffic and map an exact request URL to a local file. Run it
against a dedicated browser profile, route that browser through the proxy, and
trust its local CA in that investigation environment for HTTPS. This avoids a
DevTools connection for capture or response replacement; it does not guarantee
the site accepts a proxy. See [certificate setup](https://docs.mitmproxy.org/stable/concepts/certificates/).

After obtaining and editing a particular script, the documented mapping format
allows a command shaped like this; the hostname and path are placeholders:

```bash
mitmproxy --set 'map_local=|^https://example\.com/assets/detector\.js$|/tmp/detector-patched.js'
```

Keep the original, edited copy, and exact mapping together. If interception
misses the request, check the browser's route and cached response before changing
the patch. `anticache` removes conditional-request headers but is not a universal
browser-cache bypass. See [Map Local and Anticache](https://docs.mitmproxy.org/stable/overview/features/).

Firefox also provides
[`webRequest.filterResponseData`](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/API/webRequest/filterResponseData)
to inspect or modify response streams with the required permissions. This can
support a Firefox-only helper; it is not a portable Chromium API, and the
project's MV3-to-MV2 packager does not supply an equivalent implementation.

Sanitize captured cookies, authorization headers, and sensitive response data
before sharing or committing evidence, as required by the existing site guide.

## 5. Automation and modified-browser options

Playwright provides `addInitScript` before page scripts and `route` to abort or
replace requests. Install routes before navigation. Requests handled by service
workers need separate consideration; the docs recommend `serviceWorkers: 'block'`
for interception, which changes the browsing environment. See
[BrowserContext](https://playwright.dev/docs/api/class-browsercontext).
Switching automation libraries alone does not establish detector resistance.

[Rebrowser patches](https://github.com/rebrowser/rebrowser-patches) target
specific Puppeteer/Playwright instrumentation leaks, including `Runtime.enable`.
Its maintainers acknowledge source-patching fragility. This is a candidate only
after diagnosing that signal, with versions pinned and behavior compared against
an ordinary browser. It does not automatically restore the visible DevTools UI.

[Patchright](https://github.com/Kaliiiiiiiiii-Vinyzu/patchright) is a patched
Playwright implementation for Chromium. Its documented avoidance of Console
instrumentation trades away console functionality. It does not support Firefox
or WebKit. These are upstream claims, unverified in our environment, and neither
project was installed or integrated with the pinned Chrome DevTools MCP here.

A custom browser build could change detector-observable behavior, but we found
no basis to recommend one as a general solution for Lunarx. Maintaining it would
add a separate browser and tooling compatibility obligation. Historical research
on several distinct side channels explains why changing a single behavior is
insufficient: [Musch and Johns, USENIX Security 2021](https://www.usenix.org/conference/usenixsecurity21/presentation/musch).

[Eruda](https://github.com/liriliri/eruda) provides an in-page console and
inspection UI as another way to collect evidence. It is not a replacement for
the browser debugger, and the candidate libraries explicitly include Eruda
detection, so it ranks below a small purpose-built DOM snapshot here. See the
checker evidence in the [library report](devtools-blocker-research.md).

## Next investigation on Lunarx

1. Recover the saved detector bundle/repository reference from the previous
   investigation; establish the exact startup call and configured options.
2. Use existing API evidence and extension snapshots for parser questions they
   can answer. Keep one chapter request at a time and the parser's throttle.
3. If interactive debugging is needed, prepare a precise startup-call override.
   Use proxy replacement if establishing a DevTools override triggers the block.
4. Record the browser/tool version, bundle hash, original symptom, narrow change,
   and resulting DOM/network availability. Undo the change and compare behavior
   before claiming that it explains the detector.
5. Keep investigation changes separate from production parser behavior. A page
   working only with modified scripts does not establish that a normal user can
   download chapters.

This research changed documentation only. Run `just build` for repository
validation and report it as build/lint evidence. It does not validate the proposed
bypasses or confirm chapter downloads.

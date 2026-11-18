# Research: JavaScript DevTools blockers

**Reviewed:** November 17, 2026  
**Scope:** Public source code and documentation for `theajack/disable-devtool` and `AEPKILL/devtools-detector`. No live Lunarx inspection or blocker test was performed.

## Lunarx identification remains unconfirmed

The repository's [site investigation guidance](site-investigation.md) records that Lunarx reacts to DevTools connections. It does not identify the JavaScript library, and the parser source does not establish which library was served. The techniques below describe two candidate projects, not a confirmed attribution to Lunarx. To identify a deployed copy, compare a saved, sanitized script response or a source map with these repositories; do not infer identity from the page's reaction alone.

## Detection techniques found in the source

These projects use browser-visible side effects as heuristics. They do not prove that DevTools is open, and the results depend on browser, version, DevTools panel, and connection method.

| Technique | What the code observes | Source and caveat |
|---|---|---|
| Viewport dimensions | Difference between outer and inner window dimensions, which can change when tools are docked | `disable-devtool` has a `Size` detector; its default config excludes it. [Detector enum](https://github.com/theajack/disable-devtool/blob/master/src/utils/enum.ts), [default config](https://github.com/theajack/disable-devtool/blob/master/src/utils/config.ts) |
| Console serialization side effects | Whether logging values causes DevTools to call custom serialization behavior on RegExp, functions, dates, or DOM elements | `devtools-detector` documents these as deprecated in modern Chrome, where DevTools can fetch values through V8 APIs instead. [Project explanation](https://github.com/AEPKILL/devtools-detector/blob/master/HOW_IT_WORKS.md) |
| Console timing / large objects | Time spent logging large structures; the open console may materialize more display nodes | Described as a currently used method by `devtools-detector`. Timing is inherently browser- and load-dependent. [Project explanation](https://github.com/AEPKILL/devtools-detector/blob/master/HOW_IT_WORKS.md), [checker source](https://github.com/AEPKILL/devtools-detector/blob/master/src/checkers/performance.checker.ts) |
| `debugger` timing | Whether a `debugger` statement pauses execution long enough to cross a timing threshold | Both projects include a debugger probe. AEPKILL calls it a fallback that affects user experience; `disable-devtool`'s own implementation enables it only for iOS Chrome/Edge. [AEPKILL explanation](https://github.com/AEPKILL/devtools-detector/blob/master/HOW_IT_WORKS.md), [disable-devtool checker](https://github.com/theajack/disable-devtool/blob/master/src/detector/sub-detector/debugger.ts) |
| Custom formatters | Whether DevTools invokes registered `devtoolsFormatters` hooks | Present in AEPKILL's checker list; the project notes this depends on custom formatters being enabled. [Checker source](https://github.com/AEPKILL/devtools-detector/blob/master/src/checkers/devtools-formatters.checker.ts), [explanation](https://github.com/AEPKILL/devtools-detector/blob/master/HOW_IT_WORKS.md) |
| Worker timing | Timing differences from work delegated to a worker | AEPKILL includes this checker in source, but it is commented out in the package's default checker list. [Checker list](https://github.com/AEPKILL/devtools-detector/blob/master/src/index.ts), [checker source](https://github.com/AEPKILL/devtools-detector/blob/master/src/checkers/worker-performance.checker.ts) |
| Embedded debugging libraries | Presence or activity of tools such as Eruda and vConsole | `disable-devtool` has a `DebugLib` detector; AEPKILL's current default list includes its Eruda checker. This identifies in-page debugging tools rather than the browser's DevTools panel. [Detector enum](https://github.com/theajack/disable-devtool/blob/master/src/utils/enum.ts), [AEPKILL default list](https://github.com/AEPKILL/devtools-detector/blob/master/src/index.ts) |

The current AEPKILL default list runs the Eruda, element-ID, custom-formatter, performance, and debugger checkers. The RegExp/function/date serialization and worker checkers exist in the repository but are commented out in that list. The detector exposes `launch()`, `stop()`, `isLaunch()`, `setDetectDelay()`, and listener management, so its response to an open-tools signal is application code attached by the site rather than a fixed redirect built into the detector. [Default list and exports](https://github.com/AEPKILL/devtools-detector/blob/master/src/index.ts), [detector class](https://github.com/AEPKILL/devtools-detector/blob/master/src/classes/devtools-detector.ts).

`disable-devtool` additionally blocks common keyboard shortcuts and can disable the context menu. Those actions interfere with opening tools but are distinct from its repeated detection loop. Its configured response can close, redirect, invoke a callback, or rewrite the page. [Key/menu handlers](https://github.com/theajack/disable-devtool/blob/master/src/utils/key-menu.ts), [configuration defaults](https://github.com/theajack/disable-devtool/blob/master/src/utils/config.ts), [close/redirect handler](https://github.com/theajack/disable-devtool/blob/master/src/utils/close-window.ts).

## Library-specific observations for investigation

### `theajack/disable-devtool`

The project supports npm and script-tag integrations. Its `disable-devtool-auto` attribute enables automatic script initialization. The exported API is a function with `isSuspend` and other properties; it is not the options call's return value. Configuration includes an MD5 token, parameter name, detector selection, ignore predicate, and callbacks. [README installation](https://github.com/theajack/disable-devtool#1-quick-use), [script initializer](https://github.com/theajack/disable-devtool/blob/master/src/plugins/script-use.ts), [API type](https://github.com/theajack/disable-devtool/blob/master/src/type.d.ts), [exported function](https://github.com/theajack/disable-devtool/blob/master/src/main.ts).

The library has an owner-configured access key mechanism: if the site sets an MD5 value, startup compares it with the configured token parameter (default `ddtk`) before enabling detection. The source reads a normal query string; when `location.search` is empty, it also extracts a `?name=value` portion inside the fragment. Thus `?ddtk=...` and `#/route?ddtk=...` are recognized forms; a plain `#ddtk=...` is not. The matching digest must be configured by the site. The `ondevtoolopen`/`url` precedence comment in config concerns the response or redirect destination; it does not override the separate token check in startup. [Startup/token check](https://github.com/theajack/disable-devtool/blob/master/src/main.ts), [URL parsing](https://github.com/theajack/disable-devtool/blob/master/src/utils/util.ts), [config comment/defaults](https://github.com/theajack/disable-devtool/blob/master/src/utils/config.ts).

The `isSuspend` boolean belongs to the exported `DisableDevtool` function/object, not to the `{success, reason}` result from calling it. In an authorized module context, the supported pause/resume form is:

```js
import DisableDevtool from 'disable-devtool';

DisableDevtool.isSuspend = true;  // pause detection
DisableDevtool.isSuspend = false; // resume detection
```

For a script-tag distribution, the README examples use a `DisableDevtool` global; confirm that name exists in the loaded build before calling it. Suspension only skips the detector loop: it does not remove the script or undo keyboard/context-menu handlers. `isRunning` reports initialization, not whether detection has fired. [API type](https://github.com/theajack/disable-devtool/blob/master/src/type.d.ts), [interval loop](https://github.com/theajack/disable-devtool/blob/master/src/utils/interval.ts), [initialization](https://github.com/theajack/disable-devtool/blob/master/src/main.ts), [script-tag API example](https://github.com/theajack/disable-devtool#13-false-trigger-problem-location-help).

With a standalone CDN script, the saved request list may expose a discrete dependency. With npm/bundled deployment, the code may instead be embedded in an application chunk, leaving no separate request to identify. The project recommends npm integration partly because a separately referenced script can be intercepted. [README integration note](https://github.com/theajack/disable-devtool#31-configuration-parameters-when-using-npm).

### `AEPKILL/devtools-detector`

This package exports a singleton detector and named `stop()` function. In an authorized module context, call:

```js
import { stop } from 'devtools-detector';

stop();
```

The source also exports the singleton as the default object, so `detector.stop()` works after `import detector from 'devtools-detector'`. The non-module browser global shown in the README is `devtoolsDetector`; a global is not created by the ES module import itself, so check which distribution the page loaded. Since the detection loop awaits checker results before checking its stopped flag, an in-flight checker may still broadcast once after `stop()`; stopping detection cannot reverse an earlier redirect or restore removed content. [Exports](https://github.com/AEPKILL/devtools-detector/blob/master/src/index.ts), [class implementation](https://github.com/AEPKILL/devtools-detector/blob/master/src/classes/devtools-detector.ts), [README usage](https://github.com/AEPKILL/devtools-detector#types--api).

The README advises loading the detector before other scripts and records a Firefox limitation for undocked DevTools: detection may occur only after switching to Console. Treat these as project guidance, not guarantees across versions. [README caveats](https://github.com/AEPKILL/devtools-detector#caveats).

## Practical limits and cautions

- Detection is heuristic and version-sensitive. The `disable-devtool` README documents cases where the library is running but none of its probes fire. [README troubleshooting](https://github.com/theajack/disable-devtool#13-false-trigger-problem-location-help).
- A detector package alone does not explain what the site does after detection. Inspect the caller/listener and the timing of its action in saved source or a sanitized capture.
- A query/hash token is an opt-in developer feature configured by the site owner, not a generic browser escape hatch. Assume it is unavailable unless the site's own configuration reveals it.
- Do not remove `debugger` statements mechanically without checking surrounding control flow: the timing result may feed a detector, but minified application code can also use `debugger` for unrelated reasons.
- Do not infer that a site uses either candidate from the behavior that the page blanks, redirects, or clears content. Establish attribution from a saved bundle, source map, dependency metadata, or other direct artifact.

## Primary sources

- [theajack/disable-devtool repository](https://github.com/theajack/disable-devtool)
- [disable-devtool README](https://github.com/theajack/disable-devtool/blob/master/README.md)
- [disable-devtool startup, token and config source](https://github.com/theajack/disable-devtool/blob/master/src/main.ts)
- [disable-devtool interval source](https://github.com/theajack/disable-devtool/blob/master/src/utils/interval.ts)
- [AEPKILL/devtools-detector repository](https://github.com/AEPKILL/devtools-detector)
- [AEPKILL README](https://github.com/AEPKILL/devtools-detector/blob/master/README.MD)
- [AEPKILL explanation of detection methods](https://github.com/AEPKILL/devtools-detector/blob/master/HOW_IT_WORKS.md)
- [AEPKILL default checker list](https://github.com/AEPKILL/devtools-detector/blob/master/src/index.ts)
- [AEPKILL detector class](https://github.com/AEPKILL/devtools-detector/blob/master/src/classes/devtools-detector.ts)

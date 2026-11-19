# Browser compatibility for parser scripts

The source manifest in `plugin/manifest.json` uses Manifest V3. The packager's
`makeManifestForFirefox()` in `eslint/pack.js` emits Manifest V2, removes the
`scripting` permission, folds host permissions into permissions, and changes
`action` to `browser_action`. Read that function when changing browser API usage.

For script injection, Chromium's MV3 package uses `scripting.executeScript()`
with `target`, `func`, and `args`. Its first frame result contains a `result` field.
The Firefox MV2 package uses `tabs.executeScript(tabId, { code, runAt })` and
returns an array of frame values directly. See `LunarxParser.readChapterSnapshot()`
and `FenrirealmParser.readChapterTab()` for existing handling of these differences.

A function serialized into a parenthesized expression must have expression-valid
syntax. An arrow-function field serializes as `(selector) => { ... }`. An ordinary
class method serializes as `waitForContent(selector) { ... }`, which fails in that
position. Keep injected functions self-contained and pass values explicitly.

The `valid-injected-function` ESLint rule checks class-member `.toString()` calls
inside injected `code` properties. It resolves same-file instance `this.member` and named
class members, then parses their source as a parenthesized function expression
without executing it. It does not resolve inherited members or arbitrary dynamic
code strings. Build success establishes syntax and lint validity within that scope.

For protected chapter text, follow the maintainer's guidance in the
[project FAQ](https://github.com/dteviot/WebToEpub/wiki/FAQ#request-to-decryptdescramble-text-for-sites-eg-chrysanthemumgarden-dragontea-ink).

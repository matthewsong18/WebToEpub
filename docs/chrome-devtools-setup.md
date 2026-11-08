# Set up a local agent browser with Chrome DevTools MCP

This guide uses the Chromium supplied by this project's devenv. It runs the real
WebToEpub extension in a dedicated local browser so an agent can investigate a
site, reload parser changes, inspect failures, and verify the resulting EPUB.

The repository's devenv supplies the browser, launcher, and project-local Codex
MCP entry. This works with standalone Nix; it does not require NixOS or changes to
your personal `~/.codex/config.toml`.

## 1. Check the development environment

Run from the repository root on your Linux desktop:

```bash
devenv shell -- chromium --version
devenv shell -- webtoepub-browser-mcp --help
```

The first command builds the environment if necessary. The second downloads the
pinned official npm package on first use and checks the launcher's options. It
prints help and exits; it does not open a browser.

[devenv.nix](../devenv.nix) adds `pkgs.chromium` and `pkgs.unzip`, and defines
`webtoepub-browser-mcp`. The launcher selects Node 24 LTS explicitly and pins
`chrome-devtools-mcp` to `1.12.0`. It passes:

- The Nix Chromium executable directly, avoiding browser auto-discovery.
- `.devenv/state/agent-chromium` as a persistent browser profile.
- The repository as an allowed filesystem root.
- `--categoryExtensions` to expose extension lifecycle tools.
- Switches disabling MCP usage statistics and performance CrUX requests.

The browser version comes from `devenv.lock`. The MCP package version is pinned
in the launcher, but npm still resolves its transitive dependencies; this is not
a fully Nix-packaged or npm-lockfile-pinned MCP installation. Once cached, the
launcher can reuse npm's downloaded package. It does not add browser tooling to
the extension's runtime dependencies.

Verified locally on 2026-11-08 with Chromium `155.0.8059.39` and MCP `1.12.0`:
the environment evaluated, the launcher exposed the extension tools, a visible
browser started, the freshly built WebToEpub `1.0.14.74` installed, and triggering
its action opened the conversion tab with `main` loaded and the source-tab query
parameter present. `just build` passed. This was a direct MCP connection check
using a separate diagnostic profile. The subsequent devenv-generated project
config was recognized as enabled by `codex mcp get webtoepub_browser --json`,
and its direct Nix launcher reported MCP `1.12.0`. Personal Codex settings were
not changed; a live-site chapter-to-EPUB run was not performed.

Use a desktop session with a working display. Adding a browser package to a
container does not also provide desktop display access. Keep the browser and MCP
server on the host initially; the existing Podman build can remain separate.

Sources: [devenv packages](https://devenv.sh/packages/),
[devenv scripts](https://devenv.sh/scripts/),
[Chrome DevTools MCP package and requirements](https://github.com/ChromeDevTools/chrome-devtools-mcp),
[server configuration](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/configuration.md).

## 2. Load the project-local MCP configuration

Entering the environment in step 1 generates `.codex/config.toml` using devenv's
`files` option. Its source of truth is the `files.".codex/config.toml".toml`
section of [devenv.nix](../devenv.nix). Edit that Nix section to change the MCP
settings, then enter the environment again.

The generated file points directly to the launcher's absolute Nix store path,
sets the working directory to this checkout, and forwards the desktop display
variables. Codex does not need to inherit the devenv shell's PATH or launch a
nested shell. The generated file is ignored by version control because its
paths are specific to this machine and checkout.

If `.codex/config.toml` is already a regular file, devenv reports a conflict
rather than overwriting it. Merge its existing project settings into the Nix
section and move the old file aside before generating the managed file.

Restart or reopen Codex in this project after the file is generated. Codex loads
project-local settings only for trusted projects. In Codex CLI, run
`codex mcp list` from this checkout to check registration; `/mcp` shows active
servers. Registration alone does not prove the browser can start: complete
step 4 in the client you intend to use.

After a fresh clone, moving the checkout, or updating the Nix inputs, enter
devenv again before opening Codex. Prepare the npm download with step 1 so it
does not consume the initial MCP startup timeout. The project config is scoped
to this repository, not to whether a devenv shell is currently open; leaving
the shell does not disconnect an already-running Codex session.

The server launches the dedicated browser when a browser tool is first used.
You do not need to open a remote-debugging TCP port or attach your everyday
browser. Only one server instance should own this profile at a time. For
concurrent sessions, set `WEBTOEPUB_BROWSER_PROFILE` to a different absolute
directory in each server's environment. Do not append another `--userDataDir`:
the MCP argument parser treats repeated string options as arrays.

Sources: [Codex MCP configuration](https://developers.openai.com/codex/mcp),
[trusted project configuration](https://learn.chatgpt.com/docs/config-file/config-advanced),
[devenv file generation](https://devenv.sh/reference/options/#filesnametoml),
[DevTools MCP browser profiles](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/advanced-usage.md).

## 3. Prepare the current extension

Build and lint using the repository's existing workflow:

```bash
just build
```

Extract the Chrome ZIP into an unpacked directory. In a Bash shell at the
repository root:

```bash
devenv shell
version=$(node -p "require('./plugin/manifest.json').version")
extension_dir="$PWD/.devenv/state/chrome-extension"
mkdir -p "$extension_dir"
unzip -o "eslint/WebToEpub${version}.zip" -d "$extension_dir"
printf '%s\n' "$extension_dir"
```

Give the printed absolute directory to the agent. Its root must contain
`manifest.json` and `popup.html`.

Use the Chrome `.zip`, not the Firefox `.xpi`. Packaging rewrites the source
manifest differently for each browser. Loading this extracted build checks the
Chromium manifest users actually receive. Loading `plugin/` directly can help
with rapid edits, but is a different artifact and should be identified as such.

Sources: [packager](../eslint/pack.js), [source manifest](../plugin/manifest.json),
[build recipe](../justfile).

## 4. Verify the connection and extension

Ask the agent to perform this sequence with the connected tools:

1. Call `list_pages` to confirm the browser starts.
2. Call `install_extension` with the absolute directory from step 3. Record its
   returned extension ID, then confirm WebToEpub appears in `list_extensions`.
3. Open the book URL being investigated and select that page.
4. Call `trigger_extension_action` with the extension ID.
5. Call `list_pages` again and inspect WebToEpub's newly opened conversion tab.

Confirm the expected parser name, story title/author, completed chapter list,
ordering, and locked/unreleased checkbox defaults. Then select a small known-free
chapter sample, pack an EPUB, and inspect the downloaded file. A successful
download alone is insufficient: confirm every selected chapter is present and
contains actual story content. Record the source revision, browser version,
extension ID/path, URLs checked, and observed results.

The agent can use `take_snapshot`, `take_screenshot`, `list_console_messages`,
and `list_network_requests` for evidence. `evaluate_script` inside the extension
tab can inspect `main.getCurrentParser()` when a failure needs diagnosis. Use
the normal UI flow for the final verification.

WebToEpub opens `popup.html?id=<source-tab-ID>` from its action. Do not start by
navigating to bare `popup.html`, and do not assume a DevTools page ID is a Chrome
tab ID. There is no background service worker in this extension's manifest, so
do not wait for one to discover its ID.

Sources: [extension tools](https://developer.chrome.com/docs/devtools/agents/extensions),
[tool reference](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/tool-reference.md),
[UI startup](../plugin/js/main.js), [chapter UI](../plugin/js/ChapterUrlsUI.js).

## 5. Repeat after a parser edit

1. Run `just build` and repeat the extraction commands from step 3. Re-read the
   version if the manifest changed.
2. Call `reload_extension` with the recorded extension ID. Close any old conversion
   tab and trigger the extension action again from the source book page.
3. Repeat the same chapter sample and inspect the new output.

Reloading the extension without updating its extracted directory tests the old
code. If you delete or rename packaged files, use a fresh staging directory and
install it again so old extracted files cannot linger.

Keep normal parser throttling and one chapter fetch at a time. Record the
profile's preferences; reading-list history can deselect chapters, and
skip-failed-chapter behavior can hide incomplete downloads. A challenge, expired
login, rate limit, or unavailable site should be reported separately from a
confirmed parser failure. This setup does not bypass those conditions.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| MCP entry is missing | Restart the client; verify TOML, the absolute devenv path, and `cwd`. |
| MCP startup times out | Run step 1 in a terminal first; check npm access and Nix build errors. |
| No browser executable | Run `devenv shell -- chromium --version`; the launcher must use this checkout's devenv. |
| Browser cannot open a window | Check the desktop session and forwarded display variables; run the server on the host. For unattended diagnosis, the launcher accepts `--headless`, but that does not verify the visible desktop session. |
| Profile is already in use | Stop the other server/browser using the dedicated profile, or choose another profile. |
| Extension tools are missing | Confirm server version and `--categoryExtensions`; restart after changing it. |
| `Access denied` installing the extension | Keep the unpacked directory inside the repository; the launcher restricts file access to that root. |
| Extension appears unchanged | Rebuild, re-extract the current version, reload, and open a fresh conversion tab. |
| CAPTCHA, login, or 429 | Record the blocked check and stop repeated requests; resume after the access issue is resolved. |

Do not add `--no-sandbox` or disable certificate validation as a default fix for
browser startup issues. Diagnose the actual environment failure first.

## Scope

The dedicated profile and extracted extension live under the already-ignored
`.devenv/` directory. The generated `.codex/config.toml` registers the MCP server
for this trusted project; your personal Codex configuration is not changed.
This does not schedule site monitoring. For repeatable live checks and
monitoring, see the [research proposal](research/local-browser-parser-validation.md).

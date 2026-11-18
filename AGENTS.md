# WebToEpub agent guide

WebToEpub converts web novels into EPUBs. Chromium ships as Manifest V3;
Firefox packaging converts the source manifest to Manifest V2.

## Navigation

- Before creating or modifying a parser, read [the parser reference](docs/parsers/reference.md), then consult `plugin/js/Parser.js`, `plugin/js/HttpClient.js`, and `plugin/js/Util.js` for the APIs you need.
- For tab capture or injected scripts, read [browser compatibility](docs/parsers/browser-compatibility.md). Firefox manifest conversion lives in `eslint/pack.js`.
- Before investigating a site through browser tools, read [site investigation](docs/parsers/site-investigation.md), especially for sites that detect DevTools.
- During review, read [coding standards](CODING_STANDARDS.md) and [the contributor checklist](CONTRIBUTING.md).

## Parser workflow

- Create parsers from `plugin/js/parsers/Template.js`. Register new files in `plugin/popup.html`, keeping parser script tags alphabetized. Packaging discovers scripts through this page.
- New AI-created parser files start with `// Ai generated + <Ai model>`, followed by `"use strict";`.
- Keep chapter fetch concurrency at one. Respect the parser's minimum throttle.
- Return chapter objects with `sourceUrl`, `title`, and optional `isIncludeable`. Default paid, locked, scheduled, or non-story entries to unchecked.
- AI agents must not create parser unit tests or fixtures in `unitTest/` or `testdata/`.

## Validation and revisions

- Run only `just build` for validation. This project instruction takes precedence over generic skill steps requesting TDD, test suites, typechecking, or browser checks. See [the contributor checklist](CONTRIBUTING.md) for what the build establishes.
- Use the JJ MCP for status, history, diffs, descriptions, and commits.
- Use descriptive change summaries such as `fix:`, `feat:`, `refactor:`, and `build:`.

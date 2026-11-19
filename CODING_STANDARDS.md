# Coding standards for review

- Follow surrounding vanilla JavaScript conventions and reuse the base parser and `util` APIs. Keep external npm dependencies out of client-side parser scripts.
- Preserve user preferences. New optional behavior belongs in `populateUIImpl()` and defaults to off or the safe existing behavior.
- Choose a minimum throttle appropriate to the site. Keep chapter-fetch concurrency at one and delays at least as long as the minimum throttle.
- For constructed chapter documents, pair `Parser.makeEmptyDocForContent()` with `Parser.findConstructedContent()` so the normal download pipeline can find the content.
- When reviewing browser API changes, consult [browser compatibility](docs/parsers/browser-compatibility.md) and assess both packaged variants. Consider API availability, permission differences, returned values, and tab/listener cleanup together.
- Use API metadata through the corresponding parser extraction hooks. Check that stored metadata has a consumer.

ESLint owns mechanical JavaScript rules, including serialized injection syntax.
See `eslint/.eslintrc.js` and `eslint/rules/valid-injected-function.js`.
The authoring workflow and new-file requirements live in [AGENTS.md](AGENTS.md).

## Pull Request Check List
* Does `just build` pass? It runs `nix build`, whose build phase runs `npm run lint`. That command packages the Chrome ZIP and Firefox XPI, runs ESLint, and checks serialized class functions used in injected code. Artifacts are under `result/`.
* Report build/lint results as build/lint results. Chapter downloading is verified only when the user supplies manual confirmation.
* If you've added new behavior, 
    * Can a user turn it off?  
    * Is it off by default?  Note, users don't like it when behavior changes without warning.
* Have you updated the "contributors" section of packages.json with your name? (and ideally email, so I can contact you easily.)
* Have you updated the "Credits" section of readme.md with your name?
* Are you committing to the ExperimentalTab branch?
* Have you rebased your commit?

## Validation workflow

Run only `just build` for validation. Generic implementation skills requesting
TDD, typechecking, full test suites, or browser checks yield to this project
workflow. Existing QUnit files are legacy material and are outside this workflow.
`npm test` starts a static server; it does not execute a test suite.

During review, consult [coding standards](CODING_STANDARDS.md). Browser tools
are optional investigation tools described in [site investigation](docs/parsers/site-investigation.md).

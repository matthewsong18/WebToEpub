# Parser reference

Read this when creating or modifying a parser. Source implementations are authoritative for API details.

## Core APIs

Before implementing or modifying a parser, study these three core files. They provide the complete foundation and utility toolset for WebToEpub:

### 1. `plugin/js/Parser.js` — Base Parser Class
The base class `Parser` provides the entire download orchestration, DOM sanitization lifecycle, rate limiting, and metadata processing.

Key functions, properties, and hooks available to your parser:
- **Rate limiting & Throttle**:
  - `this.minimumThrottle`: Minimum delay (in ms) between HTTP requests (default: `500`). Increase this (e.g., `3000` to `12000`) for Cloudflare-protected or heavily rate-limited sites.
  - `this.maxSimultanousFetchSize`: Number of concurrent chapter fetches should stay as 1. Never change this. `this.rateLimitDelay()` should be set at least to `this.minimumThrottle`.
- **TOC & Pagination Helpers**:
  - `walkTocPages(dom, chaptersFromDom, nextTocPageUrl, chapterUrlsUI)`: Sequentially crawls Table of Contents pages while updating UI progress until `nextTocPageUrl` returns `null`.
  - `getChaptersFromAllTocPages(chapters, extractPartialChapterList, urlsOfTocPages, chapterUrlsUI, wrapOptions)`: Fetches a known list of TOC URLs and aggregates chapters.
  - `getChapterUrlsFromMultipleTocPages(dom, extractPartialChapterList, getUrlsOfTocPages, chapterUrlsUI)`: High-level helper combining page URL extraction and fetching.
  - `walkPagesOfChapter(url, moreChapterTextUrl)`: Handles multi-page chapters by chasing "next page" links and merging content elements.
  - **Chapter Object Structure & `isIncludeable`**:
    `getChapterUrls(dom, chapterUrlsUI)` returns an array of chapter objects: `{ sourceUrl, title, isIncludeable? }`.
    - `isIncludeable` (boolean, defaults to `true` if omitted): Controls the default checkbox state of each chapter in the WebToEpub popup UI and dictates whether it will be downloaded/packaged.
    - Set `isIncludeable: false` for paywalled, VIP, coin/points locked, premium, unreleased, or non-story chapters (e.g. `isIncludeable: !chapter.is_locked` or `isIncludeable: chapter.isFree`).
    - Chapters with `isIncludeable: false` appear in the popup UI unchecked by default, preventing failed fetches or empty chapters, while still allowing users who have unlocked or purchased the content to manually check them.
- **Constructed / In-Memory Content Helpers**:
  - `Parser.makeEmptyDocForContent(baseUrl)`: Creates a synthetic HTML DOM (`{ dom, content }`) for parsers that construct chapters from JSON or custom text instead of scraping raw HTML pages.
  - `Parser.findConstructedContent(dom)`: Standard selector (`div.webToEpubContent`) to retrieve content created via `Parser.makeEmptyDocForContent`.
  - `Parser.addTextToChapterContent(newDoc, contentText)`: Splits raw text by newlines and wraps lines in `<p>` tags inside `newDoc`.
- **Metadata Extraction Hooks**:
  - `extractTitle(dom)` / `extractTitleImpl(dom)`: Returns story title (element or string).
  - `extractAuthor(dom)`: Returns author name string (fallback: `super.extractAuthor(dom)`).
  - `extractLanguage(dom)`: Returns ISO language code (e.g. `"en"`).
  - `extractSubject(dom)` / `extractDescription(dom)` / `extractPublisher(dom)` / `extractDatePublished(dom)`: Additional EPUB metadata fields.
  - `findCoverImageUrl(dom)`: Returns URL of the novel cover image.
- **DOM & Content Cleaning Lifecycle**:
  - `findContent(dom)`: **Mandatory**. Returns the DOM element containing chapter content.
  - `findChapterTitle(dom)`: Extracts chapter title if located outside the content element.
  - `preprocessRawDom(webPageDom)`: Modifies raw chapter DOM before content extraction (e.g., reformatting author notes).
  - `removeUnwantedElementsFromContentElement(element)`: Strips ads, share buttons, or navigation elements from the extracted content.
  - `customRawDomToContentStep(chapter, content)`: Custom DOM transformation step. For protected text, consult the [project FAQ](https://github.com/dteviot/WebToEpub/wiki/FAQ#request-to-decryptdescramble-text-for-sites-eg-chrysanthemumgarden-dragontea-ink).
- **Custom Error & Challenge Handling**:
  - `isCustomError(response)`: Returns `true` if response represents a challenge/captcha or custom site failure.
  - `setCustomErrorResponse(url, wrapOptions, checkedresponse)`: Returns custom retry behavior, delay sequence, or status (e.g. `403` to prompt user for captcha, `999` for auto-retry).
  - `isNoContentToError403AndContentNull(response)`: Intercepts empty content pages as potential 403 blocks.

---

### 2. `plugin/js/HttpClient.js` — HTTP Client & Network Layer
Wraps the browser Fetch API with cookie handling, declarative header manipulation, and automatic retries.

Key methods and features:
- **`HttpClient.wrapFetch(url, wrapOptions)`**:
  - Main method for fetching HTML web pages. Returns a promise resolving to a response object with `.responseXML` (parsed HTML document) and `.response` (raw `Response`).
  - Automatically sets and unsets partitioned cookies.
  - Automatically retries on common transient HTTP errors (429, 500, 502, 503, 504, 520, 522, 524).
- **`HttpClient.fetchJson(url, fetchOptions)`**:
  - Fetches and parses JSON from REST endpoints: `let data = (await HttpClient.fetchJson(url, options)).json;`.
  - Supports passing `{ parser: this }` in `fetchOptions` to enable `isCustomError` handling.
- **`HttpClient.fetchText(url, fetchOptions)`**:
  - Fetches raw text content from an endpoint.
- **`HttpClient.fetchHtml(url)`**:
  - Fetches and returns parsed HTML DOM.
- **`HttpClient.setDeclarativeNetRequestRules(rulesArray)`**:
  - Modifies outgoing request headers using Chrome/Firefox `declarativeNetRequest` API (e.g., spoofing `referer`, `sec-fetch-*` headers for Cloudflare-protected sites).

---

### 3. `plugin/js/Util.js` — DOM, URL & String Utilities (`util.*`)
Provides dozens of tested utility functions for scraping and DOM manipulation. Always check `Util.js` before writing custom regex or DOM loops.

Commonly used functions:
- **Chapter Link Extraction**:
  - `util.hyperlinksToChapterList(element)`: Converts all child `<a>` links inside an element into an array of `{ sourceUrl, title }`.
  - `util.hyperLinkToChapter(aElement)`: Converts a single `<a>` tag into `{ sourceUrl, title }`.
- **Element Removal & Filtering**:
  - `util.removeChildElementsMatchingSelector(element, selector)`: Removes descendants matching a CSS selector.
  - `util.removeElements(nodeListOrArray)`: Removes a collection of elements from the DOM.
  - `util.removeComments(node)`: Strips HTML comments.
  - `util.removeUnwantedWordpressElements(element)`: Removes standard WordPress garbage (sharing widgets, metadata, etc.).
  - `util.removeShareLinkElements(element)`: Strips social sharing links.
  - `util.removeEmptyDivElements(element)`: Strips empty `<div>` containers.
  - `util.removeLeadingWhiteSpace(element)` / `util.removeTrailingWhiteSpace(element)`: Trims whitespace nodes.
- **Images & Formatting**:
  - `util.getFirstImgSrc(dom, containerSelector)`: Finds the first `<img>` within container and returns its URL.
  - `util.convertPreTagToPTags(dom, preElement, delimiter)`: Converts `<pre>` blocks into proper `<p>` elements.
  - `util.moveChildElements(sourceElement, targetElement)`: Moves all children from source into target.
  - `util.sanitize(htmlString)`: Sanitizes HTML strings via DOMPurify.
- **URL & String Manipulation**:
  - `util.normalizeUrlForCompare(url)`: Normalizes URLs for comparison (stripping protocol, trailing slashes, fragments).
  - `util.safeForFileName(title, maxLen)`: Sanitizes string for safe filesystem usage.
  - `util.isNullOrEmpty(str)`: Checks for null, undefined, or empty string.
  - `util.sleep(ms)`: Async sleep utility.

---

## Parser implementation template

Use `plugin/js/parsers/Template.js` as the boilerplate when creating a new parser.
Keep JavaScript in strict mode. Implement `getChapterUrls`, `findContent`,
`extractTitleImpl`, and `extractAuthor`, using base-parser fallbacks where appropriate.
Place the new-file AI header before the strict-mode directive as described in
[AGENTS.md](../../AGENTS.md).

### Anatomy of a Parser:
```javascript
// Ai generated + <Ai model>
"use strict";

// 1. Registration with parserFactory
parserFactory.register("example.com", () => new ExampleParser());

class ExampleParser extends Parser {
    constructor() {
        super();
        // Optional: throttle in ms between chapter fetches
        this.minimumThrottle = 2000;
    }

    // 2. Fetch or extract list of chapters: [{ sourceUrl, title, isIncludeable? }]
    //    `isIncludeable: false` unchecks chapter in popup UI by default (e.g. for locked/VIP/paid chapters)
    async getChapterUrls(dom, chapterUrlsUI) {
        let menu = dom.querySelector("div.chapter-list");
        return util.hyperlinksToChapterList(menu);
    }

    // 3. Find content node for each chapter
    findContent(dom) {
        return dom.querySelector("article.entry-content");
    }

    // 4. Story title
    extractTitleImpl(dom) {
        return dom.querySelector("h1.novel-title");
    }

    // 5. Author name (string)
    extractAuthor(dom) {
        let authorLabel = dom.querySelector("span.author a");
        return authorLabel?.textContent ?? super.extractAuthor(dom);
    }

    // 6. Optional: cover image
    findCoverImageUrl(dom) {
        return util.getFirstImgSrc(dom, "div.cover-art");
    }

    // 7. Optional: chapter title if outside content node
    findChapterTitle(dom) {
        return dom.querySelector("h2.chapter-heading");
    }

    // 8. Optional: strip site-specific unwanted elements
    removeUnwantedElementsFromContentElement(element) {
        util.removeChildElementsMatchingSelector(element, ".advertisement, .watermark");
        super.removeUnwantedElementsFromContentElement(element);
    }
}
```

---

## Architectural patterns

Different websites require different strategies. WebToEpub contains 4 primary architectural patterns demonstrated by existing parsers:

### Pattern A: Server-Side Rendered HTML & Multi-page TOC
**Example**: `plugin/js/parsers/MznovelsParser.js`
- **When to use**: Standard websites where chapters and TOC are rendered as traditional HTML, but the TOC spans multiple paginated pages.
- **Technique**:
  - `getUrlsOfTocPages(dom)` inspects pagination controls (e.g. `.pagination`) and calculates all page URLs (`url.searchParams.set("page", i)`).
  - Uses `this.getChaptersFromAllTocPages(...)` to download all TOC pages and aggregate chapter links.
  - Uses `preprocessRawDom` to reformat author notes before content extraction (`util.convertPreTagToPTags`).

### Pattern B: Sequential TOC Crawling & Header Spoofing (Cloudflare Bypass)
**Example**: `plugin/js/parsers/ScribblehubParser.js`
- **When to use**: Sites that block requests lacking browser headers (`Referer`, `Sec-Fetch-*`) or sites where total TOC page count is dynamic.
- **Technique**:
  - Uses `HttpClient.setDeclarativeNetRequestRules(...)` to set `referer`, `sec-fetch-dest: document`, and `sec-fetch-site: same-origin`.
  - Walks TOC pages sequentially with a `while (url != null)` loop and updates UI progress with `chapterUrlsUI.showTocProgress(partialList)`.
  - Configures higher throttle: `this.minimumThrottle = 7500`.

### Pattern C: Clean REST API & Synthetic Document Construction
**Example**: `plugin/js/parsers/BotitranslationParser.js`
- **When to use**: Modern web apps where novel metadata, chapter lists, and chapter content are loaded via JSON APIs rather than server-rendered HTML.
- **Technique**:
  - Registered for multiple domains (`botitranslation.com`, `mystorywave.com`).
  - `getChapterUrls(dom)` queries a JSON endpoint: `HttpClient.fetchJson("https://api.../chapters/page?bookId=" + bookId)`.
  - `fetchChapter(url)` queries chapter JSON by ID.
  - Constructs synthetic DOM:
    ```javascript
    buildChapter(json, url) {
        let newDoc = Parser.makeEmptyDocForContent(url);
        let title = newDoc.dom.createElement("h1");
        title.textContent = json.data.title;
        newDoc.content.appendChild(title);
        let content = util.sanitize(json.data.content);
        util.moveChildElements(content.body, newDoc.content);
        return newDoc.dom;
    }
    ```
  - `findContent(dom)` simply returns `Parser.findConstructedContent(dom)`.

### Pattern D: Client-Side SPA / API + Advanced Challenge & Error Interception
**Example**: `plugin/js/parsers/WtrlabParser.js`
- **When to use**: Complex single-page apps (e.g. Next.js), sites requiring POST payload requests, glossaries/translation replacements, or custom challenge handling (Cloudflare Turnstile, locked chapters).
- **Technique**:
  - Extracts build configuration directly from `<script id="__NEXT_DATA__">`.
  - Fetches chapter content via POST requests using `HttpClient.fetchJson(url, options)`.
  - Implements `isCustomError(response)` to detect Turnstile challenges (`requireTurnstile`) or locked content (`CHAPTER_LOCKED`).
  - Implements `setCustomErrorResponse(...)` returning status `403` to prompt the user to solve a captcha, or status `999` with `retryDelay` sequence.
  - Applies custom dictionary/glossary term replacements across chapter texts.

---


# Fbooks roadmap

This is the source of truth for product progress and the order of work. Before
starting a new milestone, review this document together with
`docs/architecture.md`; update the checkbox, acceptance criteria, and commit
reference when the milestone is complete.

## Product boundary

Fbooks is a local-first reader for comics and ebooks.

- Reading experience comes before TTS and AI.
- Local files and OPDS are equal library sources.
- A format must not be offered for import or OPDS download until it can be
  opened by a reader.
- AI and TTS are intentionally deferred. Their future integrations must use
  extracted content and a stable `ReadingLocator` rather than presentation
  state.

## Current state

### Completed foundation

- [x] Clean Flutter implementation, dependency boundaries, and migratable
  SQLite metadata store (`d0f7e13`).
- [x] Persistent local library, importing, and duplicate detection
  (`2e708ed`, `3a723a1`).
- [x] Read local CBZ comics with natural page ordering and persisted page
  progress (`02fe5fe`, `746836a`).
- [x] Read local EPUB and TXT as reflowable text; restore chapter and scroll
  position (`76341e0`, `97e520b`, `d84293d`).
- [x] Browse OPDS 1 / OPDS 2 catalogs and download readable acquisitions
  (`41b62c4`, `11e5db9`).
- [x] Reader navigation controls and library-side resume labels
  (`6af659d`, `af88c30`).
- [x] Persisted comic reading modes: left-to-right, right-to-left, vertical
  paging, and horizontal double-page spreads (`be95020`).

### Current supported formats

| Source | Readable now | Deliberately not offered yet |
| --- | --- | --- |
| Local import | CBZ, EPUB, TXT | CBR, CBT, CB7, PDF |
| OPDS acquisition | CBZ, EPUB, TXT when detectable | PDF and unrecognised formats |

## Next: finish basic reading experience

This is the active product milestone. Each checked item should have its own
focused commit and pass `flutter analyze` plus `flutter test`.

- [ ] Make the vertical comic mode a continuous vertical scroll. The current
  implementation is vertical *paging*, which is useful but does not yet meet
  the intended continuous-scroll mode.
- [ ] Validate comic layouts on real phone, tablet, and desktop windows.
  Decide and implement precise fit/crop behavior for single pages, covers, and
  double-page spreads; confirm right-to-left spread order with sample manga.
- [ ] Add text-reading preferences: font size, line height, margins, and
  light/dark/sepia appearance. Persist them locally and retain the reading
  position when they change.
- [ ] Improve the text reader's EPUB presentation: preserve paragraph breaks
  and basic emphasis rather than flattening every spine item into one text
  string.
- [ ] Give every reader a clear loading, missing-file, corrupt-file, and empty
  content state.
- [ ] Add widget/integration coverage for restoring positions, mode changes,
  and double-page page mapping.

### Definition of done for basic reading

- CBZ, EPUB, and TXT can be imported, reopened, and resumed reliably.
- Comics support left-to-right, right-to-left, and continuous vertical reading;
  horizontal modes support optional spreads without losing the current page.
- Text is comfortably readable and its appearance can be adjusted without
  losing a chapter or scroll position.
- The app has been manually checked at phone, tablet, and desktop sizes in
  addition to automated analysis and tests.

## After basic reading: library and OPDS quality

- [ ] Publication details: cover, authors, description, source, format, and
  last-opened state.
- [ ] Library operations: remove a publication, retain or delete downloaded
  files deliberately, and repair a missing local file.
- [ ] Search, sort, and filter local and OPDS publications.
- [ ] OPDS catalog management: edit/remove a catalog, authentication strategy,
  retries, download progress, and cancellation.
- [ ] Refresh downloaded or remote metadata without creating duplicates.

## Later: format expansion

No format enters the import picker or OPDS acquisition flow before this work is
complete.

- [ ] PDF reader with an independent PDF locator and progress persistence.
- [ ] Additional comic containers (CBR, CBT, CB7) after selecting supported,
  maintained decoding libraries per target platform.
- [ ] EPUB rendering improvements such as images, tables, internal links, and
  table of contents.

## Deferred extensions

### Background TTS

- [ ] Playback queue and durable playback state.
- [ ] Platform background audio integration and media controls.
- [ ] Sentence/passage locator mapping so playback and reading remain synced.

### Contextual AI questions

- [ ] Extracted-content index keyed by publication revision and locator.
- [ ] Context selection, citations, and jump-to-passage behavior.
- [ ] Provider abstraction, credential storage, privacy policy, and offline
  behavior.

## Working agreement

1. Keep a meaningful commit after each independently reviewable milestone.
2. Run `flutter analyze` and `flutter test` before each feature commit.
3. Record any new product decision or scope change here before implementing a
   substantial follow-up.
4. Prefer domain ports and format-specific locators over UI-specific state.
5. When a decision materially changes reading behavior (for example a default
   page direction or crop policy), ask for confirmation rather than guessing.

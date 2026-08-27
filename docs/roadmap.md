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

## Design implementation (active)

The visual reference is the user-owned Figma Make project **PC 阅读软件**.
Its component structure covers the library, collections, comic reader, ebook
reader, and settings. Figma Make is being used as the source of interaction and
visual intent; the Flutter implementation remains the production app.

- [x] Establish a responsive desktop library shell with a persistent sidebar,
  library toolbar, and compact-window fallback (`095ebda`).
- [x] Add shared desktop-sidebar and mobile-bottom navigation for Library,
  Collections, Plugins, and Settings (`b132425`).
- [x] Replace the Collections, Plugins, and Settings UI placeholders with
  real, scoped product capabilities while keeping Library wired to real data.
  Collections are persisted locally and can contain library books; Plugins
  documents the shipped built-in integrations; Settings persists the app theme.
- [ ] Compare every finished screen with the stable Figma Make design before
  marking its UI pass complete. If pixel-level export or annotations become
  necessary, promote that screen to a standard Figma Design frame.

## Next: finish basic reading experience

This is the active product milestone. Each checked item should have its own
focused commit and pass `flutter analyze` plus `flutter test`.

- [x] Make the vertical comic mode a continuous vertical scroll. It preserves
  a page-level reading position while users scroll and can return to a chosen
  page from the reader controls.
- [ ] Validate comic layouts on real phone, tablet, and desktop windows.
  The default policy is full-page `contain` for horizontal reading and
  width-fitted, uncropped images for vertical scroll. Keep alternative
  fit/crop settings for a later reader-preferences milestone; confirm
  right-to-left spread order with sample manga.
- [x] Add text-reading preferences: font size, line height, margins, and
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

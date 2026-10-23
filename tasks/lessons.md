# Lessons

## 2026-08-29 — Do not retain overlapping built-in collection semantics

- When product feedback distinguishes a specific queue such as “Read later”,
  do not leave another system collection such as “Saved” with overlapping
  meaning. Confirm the canonical collection and remove the redundant one from
  the product model and UI.
- For Fbooks, the canonical deferred-reading collection is `Read later`; the
  previous `Reading list` label must be renamed and the `Saved` system
  collection must not be exposed or created.
- A “Finished” system collection must be driven by explicit reading-completion
  state, with automatic completion at the final valid locator and a manual
  correction action; do not infer completion from a merely recent progress
  timestamp.

## 2026-08-29 — Preserve the user's requested legacy-feature scope

- When asked to synchronise a legacy screen's capabilities, treat the audited
  legacy checklist as the delivery contract. Do not stop after implementing a
  related data-model slice while selection mode, batch actions, or the other
  named screen remains absent.
- Before reporting progress, compare every requested legacy capability against
  the current implementation and explicitly continue any unmatched item.

## 2026-08-29 — Carry over interaction structure, not just feature labels

- When a legacy screen is the explicit reference, preserve its scalable
  interaction model. For library sorting, use a sort-field choice plus a
  separate ascending/descending choice; do not flatten their Cartesian product
  into a growing list of options.
- Consolidate related filters under one overflow menu when the reference does
  so, and audit each legacy single-book action before replacing its menu.

## 2026-08-29 — Menu parity needs an explicit action matrix

- Do not call a legacy context menu synchronised after adding only a few new
  actions. Build and check off the legacy action matrix (open, details,
  favourite, completion, collection membership, deletion, and any supported
  platform action) for both single and selected books.

## 2026-08-29 — Treat collection membership as collection management

- Do not flatten a potentially long list of user-created collections into a
  context menu. For single or bulk membership changes, open a dedicated
  management surface that lets users select existing collections, create one,
  and delete custom collections while protecting system collections.

## 2026-08-29 — Preserve legacy pointer gesture semantics

- When a legacy book-library interaction is the reference, do not rely only on
  an overflow button: long press on a book must enter selection mode and select
  that book, while a pointer secondary click must open that book's single-item
  action menu at the pointer location.
- Apply the same gesture contract to both card and list representations; a
  display-mode switch must not silently remove selection or context-menu access.

## 2026-08-29 — Dark theme must cover the whole primary screen

- Do not combine a theme-aware sidebar or card with hard-coded light page
  surfaces or foreground colors in the same primary screen.
- Before claiming dark-mode support, verify Library, Collections, Plugins, and
  Settings at desktop width in both brightness modes and check text contrast
  for headings, filters, empty states, and cards.

## 2026-08-29 — Keep visible brand surfaces in sync

- When updating the launcher icon or product capitalization, audit the
  in-app brand mark, `MaterialApp.title`, and the relevant native window or
  bundle display name; changing only generated launcher assets leaves the UI
  visibly inconsistent.
- Add a widget test for the in-app brand mark and displayed name at the layout
  where the mark is visible.

## 2026-08-29 — Desktop caption must own its height outside an app bar

- `PreferredSizeWidget.preferredSize` is only applied automatically by
  `Scaffold.appBar`. When a desktop caption is embedded directly in a `Column`,
  constrain its height in the widget itself before using any expanding child.
- For responsive window chrome, add a widget test that resizes from the wide
  desktop shell to the compact shell and asserts that no layout exception is
  reported.

## 2026-08-29 — Keep primary desktop page edges on one shared grid

- Put a desktop page's heading, controls, filters, and primary content inside
  one outer padding boundary. Do not give those sections independently chosen
  horizontal margins, which makes their left edges visibly drift apart.
- When an item-level action overlays a visual card, constrain it to the visual
  hierarchy (currently 32 × 32) and use a theme-aware, subdued surface rather
  than the default large white icon-button treatment.

## 2026-08-29 — Compare legacy reader support by executable path

- When auditing whether a reader capability was inherited, follow the complete
  picker → importer → provider → session path; an enum value, presentation
  label, or archived helper alone is not evidence that the format is usable.
- For archive-memory claims, inspect the archive package's actual file-backed
  and lazy-decompression behavior before proposing a replacement; distinguish
  lazy ZIP entry access from caching decompressed page bytes in the session.

## 2026-08-29 — Honour ComicInfo page-level cover declarations

- CBZ cover selection must read `ComicInfo.xml`'s `Pages/Page` entries and
  prefer a page whose `Type` is `FrontCover` over filename and directory
  heuristics; a metadata file can define the cover even when its filename is
  non-descriptive.
- Add a regression fixture with a non-descriptive image name and a
  `FrontCover` page declaration whenever changing archive-cover selection.

## 2026-09-04 — Separate card media from card metadata padding

- When a library-card cover should be edge-to-edge, never wrap the whole card
  in a shared padding widget. Make the cover its own top media region and add
  padding only around the title, progress, and actions below it.
- Use the 1:1.6 width-to-height ebook-cover ratio for library cards, and
  calculate each tile as the cover height plus a fixed metadata-footer height
  through a custom grid delegate. Do not use the overall card aspect ratio or
  an `Expanded` metadata region, which makes text whitespace depend on width.
- Verify the computed cover and footer heights at both narrow and desktop
  widths so the metadata area cannot overflow.

## 2026-09-30 — Validate pages within chapters and responsive text layout

- Chapter navigation does not provide text pagination. Validate a long single
  TXT chapter and a long EPUB chapter with real page boundaries before claiming
  paginated reading support.
- Use the actual available viewport width and height for layout; do not silently
  cap desktop body width when the requested behavior is to fit the window.
- Keep text lines intact at page boundaries and test phone, tablet, and desktop
  widths, including resizing and typography changes while reading.
- Preserve a text anchor across reflow and reopening; retain legacy pixel
  offsets as a compatibility fallback rather than treating them as stable text
  positions. Verify both paged and continuous modes.

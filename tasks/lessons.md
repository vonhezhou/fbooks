# Lessons

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

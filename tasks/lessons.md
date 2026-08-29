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

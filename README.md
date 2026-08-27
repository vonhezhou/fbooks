# Fbooks

Fbooks is a local-first reader for comics and ebooks. It is designed around
local libraries and OPDS catalogs, with contextual AI questions and background
TTS reserved as later extensions.

## Status

This repository is a clean implementation with a working first reading slice:

- import and read local CBZ, EPUB, and TXT publications;
- browse OPDS 1 / OPDS 2 catalogs and download readable acquisitions;
- resume comics by page and text publications by chapter and scroll position;
- see the last reading position from the local library.

Other archive types and PDF are intentionally not offered for import or OPDS
download until the reader can open them. AI and TTS are not part of this
milestone.

## Development

```bash
flutter pub get
flutter analyze
flutter test
```

See [the architecture notes](docs/architecture.md) for dependency rules and
product invariants. See [the roadmap](docs/roadmap.md) for the current plan,
completed milestones, and acceptance criteria.

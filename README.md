# Fbooks

Fbooks is a local-first reader for comics and ebooks. It will support local
libraries, OPDS catalogs, contextual AI questions, and background TTS.

## Status

This repository is a clean implementation. The first milestone establishes the
application shell and domain boundaries; it does not yet persist or render a
library.

## Development

```bash
flutter pub get
flutter analyze
flutter test
```

See [the architecture notes](docs/architecture.md) for dependency rules and
product invariants.

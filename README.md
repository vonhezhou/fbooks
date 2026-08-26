# Fbooks

Fbooks is a local-first reader for comics and ebooks. It will support local
libraries, OPDS catalogs, contextual AI questions, and background TTS.

## Status

This repository is a clean implementation. It currently establishes the
application shell, domain boundaries, and a migratable local metadata store;
local-file import and reader rendering are the next milestones.

## Development

```bash
flutter pub get
flutter analyze
flutter test
```

See [the architecture notes](docs/architecture.md) for dependency rules and
product invariants.

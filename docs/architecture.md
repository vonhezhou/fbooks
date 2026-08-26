# Fbooks architecture

Fbooks is a local-first reader for comics and ebooks. A local library and an
OPDS catalog are both library sources; neither is treated as a special case by
the reader.

## Dependency direction

```text
presentation -> application -> domain <- data / infrastructure
```

- `domain` contains stable concepts and repository ports. It must not import
  Flutter, Drift, HTTP, file-system, or TTS/AI SDK types.
- `application` will coordinate import, download, reading progress, playback,
  and contextual questions through domain ports.
- `data` and `infrastructure` will implement those ports for SQLite, local
  files, OPDS, TTS, and AI providers.
- `features/*/presentation` contains widgets and feature-local state only.

## Product invariants

- Reading progress uses a format-specific `ReadingLocator`; a comic page number
  is never used as an EPUB position.
- The readable asset and the metadata record have independent lifecycles, so
  import and delete workflows can recover from partial failures.
- AI answers and TTS consume extracted content with an originating locator,
  allowing the app to cite and resume at the referenced passage.

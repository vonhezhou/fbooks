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
- `application` coordinates import, download, and format-specific reading
  progress through domain ports. Playback and contextual questions are later
  extensions.
- `data` and `infrastructure` will implement those ports for SQLite, local
  files, OPDS, TTS, and AI providers.
- `features/*/presentation` contains widgets and feature-local state only.

## Product invariants

- Reading progress uses a format-specific `ReadingLocator`; a comic page number
  is never used as an EPUB position.
- The readable asset and the metadata record have independent lifecycles, so
  import and delete workflows can recover from partial failures.
- Future AI answers and TTS will consume extracted content with an originating
  locator, allowing the app to cite and resume at the referenced passage.
- Database schema changes require an explicit migration before the schema
  version changes; an unimplemented migration fails loudly instead of risking
  the user's library data.

## Local diagnostics

- The app records structured local diagnostics in the application-support
  `fbooks/logs` directory. Logs rotate at 10 MB and retain the active file plus
  three historical files.
- Debug builds also write colourized records to the development console. The
  user chooses the minimum level retained locally; the default is `INFO` and
  the available levels are `DEBUG`, `INFO`, `WARNING`, and `ERROR`.
- Diagnostics must never include book content or titles, local absolute paths,
  OPDS credentials, authorization headers, or complete remote URLs. Prefer
  format, operation outcome, counts, and HTTP status over user data.
- Logs are local support artifacts only. Sending them off-device needs an
  explicit product, privacy, and consent decision.

## Reflowable reading

TXT, EPUB and future reflowable formats should converge on the bounded
[flow reading core](flow-reading-core.md). Format adapters own parsing,
sanitization and format-specific locator mapping; the shared Flutter renderer
only consumes the controlled flow-document model. Page-based formats such as
comics and PDF remain outside this core.

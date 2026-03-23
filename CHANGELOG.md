# Changelog

## [0.2.3] - 2026-03-22

### Changed
- Add runtime deps: legion-cache >= 1.3.11, legion-crypt >= 1.4.9, legion-data >= 1.4.17, legion-json >= 1.2.1, legion-logging >= 1.3.2, legion-settings >= 1.3.14, legion-transport >= 1.3.9
- Update spec_helper to require real sub-gem helpers and define Helpers::Lex stub with all 7 includes; require legion/transport for actor base class inheritance
- Fix transport message specs: expect raise from new instead of validate (real Message#initialize calls validate)
- Refactor Runners::Inference dispatch_chat and call_llm to resolve Metrics/ModuleLength and Metrics/MethodLength

## [0.2.2] - 2026-03-22

### Fixed
- Replace bare `Process` with `::Process` in `Runners::Inference` (6 occurrences) to avoid resolving to `Legion::Process` instead of Ruby stdlib `::Process`, which caused a `NameError` and silently failed inference calls

## [0.2.1] - 2026-03-20

### Fixed
- Add `Llm` constant alias for `LLM` so the framework can resolve `Legion::Extensions::Llm::Gateway` during extension discovery

## [0.2.0] - 2026-03-18

### Added
- Transport topology: metering (topic) and inference (direct) exchanges, queues, messages
- RPC correlation and JWT auth helpers
- Metering event builder with publish-or-spool fallback
- Inference runner: chat, embed, structured with auto-metering
- Fleet RPC dispatch runner with JWT auth and timeout
- Fleet handler for incoming inference requests
- Metering writer: consumes RMQ events, writes to DB
- Spool flush interval actor (every 60s)
- Standalone Client class with all runners

## [0.1.0] - 2026-03-18

### Added
- Initial gem scaffold
- Extension entry point and version

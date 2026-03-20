# Changelog

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

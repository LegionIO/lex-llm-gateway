# Changelog

## [0.2.6] - 2026-03-23

### Added
- Fleet dispatch for structured and embed request types from Inference runner
- Multi-message chat support in fleet dispatch (passes messages array directly)
- InferenceRequest message now includes request_type, schema, and text fields

### Changed
- Fleet.dispatch uses `**opts` for extensible parameter forwarding
- Fleet.publish_request uses anonymous keyword forwarding
- Inference extract helpers compacted to single-line ternary style

## [0.2.5] - 2026-03-23

### Added
- FleetHandler multi-request-type dispatch: structured, embed, and multi-message chat
- `call_chat` supports single and multi-message payloads
- `call_structured` dispatches to `Legion::LLM.structured` with schema
- `call_embed` dispatches to `Legion::LLM.embed` with text fallback from messages

## [0.2.4] - 2026-03-23

### Added
- Implement fleet RPC `wait_for_response` with `Concurrent::Promises` future and correlation ID matching
- Add `Helpers::ReplyDispatcher` process-singleton for managing reply queue consumer and pending futures
- Add `FleetHandler.publish_reply` to send `InferenceResponse` back to requester via AMQP default exchange

### Fixed
- Fix `Actor::InferenceWorker` runner_class mismatch: now points to `FleetHandler` instead of `Inference`
- Add `use_runner? false` to InferenceWorker so it dispatches directly to the runner module

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

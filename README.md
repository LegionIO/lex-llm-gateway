# lex-llm-gateway

LLM inference gateway for [LegionIO](https://github.com/LegionIO/LegionIO). Provides centralized metering over RabbitMQ, fleet RPC dispatch to GPU workers, and local disk spooling for offline resilience.

## Installation

Add to your Gemfile:

```ruby
gem 'lex-llm-gateway'
```

## Overview

`lex-llm-gateway` wraps all LLM calls with automatic metering and fleet routing. It is designed for clusters with 100k+ edge nodes that cannot have direct database access.

Three node roles:

| Role | What It Does |
|------|-------------|
| **Publisher** (all nodes) | Calls `Inference.chat` which auto-meters to RMQ or disk spool |
| **Fleet Worker** (GPU nodes) | Runs InferenceWorker actor, processes fleet requests |
| **Metering Writer** (DB nodes) | Runs MeteringWriter actor, writes to `metering_records` |

## Degradation Ladder

```
Full stack (transport + gateway + LLM + fleet)
  no transport  -> spool to disk, flush when reconnected
  no gateway    -> Legion::LLM direct (no metering)
  no fleet      -> local/cloud only
  no cloud      -> local LLM only
  no local      -> error
```

## Runners

- **Metering** - `build_event`, `publish_or_spool`, `flush_spool`
- **Inference** - `chat`, `embed`, `structured` (all auto-metered)
- **Fleet** - `dispatch` to GPU workers with timeout and JWT auth
- **FleetHandler** - `handle_fleet_request` (validates JWT, calls local LLM)
- **MeteringWriter** - `write_metering_record` (DB insert consumed from RMQ)

## Standalone Client

```ruby
require 'legion/extensions/llm/gateway/client'

client = Legion::Extensions::LLM::Gateway::Client.new
result = client.chat(model: 'claude-opus-4-6', messages: [{ role: 'user', content: 'Hello' }])
result[:success]  # => true
result[:response] # => "Hello! How can I help you?"
```

## Settings

```json
{
  "llm": {
    "routing": {
      "use_fleet": true,
      "fleet": {
        "timeout_seconds": 30,
        "require_auth": false
      }
    }
  }
}
```

## Requirements

- Ruby >= 3.4
- [LegionIO](https://github.com/LegionIO/LegionIO) framework
- `legion-transport` (AMQP metering + inference queues)
- `legion-crypt` (JWT signing for fleet auth, optional)
- `legion-data` (MeteringWriter and disk spool, optional)
- `legion-llm` (inference execution on fleet workers)

## Development

```bash
bundle install
bundle exec rspec     # 199 examples, 0 failures
bundle exec rubocop   # 0 offenses
```

## License

MIT

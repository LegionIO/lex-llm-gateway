# lex-llm-gateway: LLM Inference Gateway for LegionIO

**Repository Level 3 Documentation**
- **Parent**: `/Users/miverso2/rubymine/legion/extensions-core/CLAUDE.md`
- **Grandparent**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## Purpose

Centralized LLM inference gateway that wraps all LLM calls with automatic metering over RabbitMQ, fleet RPC dispatch to GPU workers, and local disk spooling for offline resilience. Designed for 100k+ edge nodes that cannot have direct DB access.

## Gem Info

- **Gem name**: `lex-llm-gateway`
- **Version**: `0.2.0`
- **Module**: `Legion::Extensions::LLM::Gateway`
- **Ruby**: `>= 3.4`
- **License**: MIT
- **GitHub**: https://github.com/LegionIO/lex-llm-gateway

## Architecture

```
Legion::Extensions::LLM::Gateway
├── Transport/
│   ├── Exchanges/
│   │   ├── Metering      # llm.metering (topic) — fan-out to multiple consumers
│   │   └── Inference      # llm.inference (direct) — point-to-point RPC
│   ├── Queues/
│   │   ├── MeteringWrite      # llm.metering.write (durable)
│   │   └── InferenceProcess   # llm.inference.process (durable)
│   └── Messages/
│       ├── MeteringEvent      # 15-field metering payload
│       ├── InferenceRequest   # model, messages, reply_to, correlation_id, JWT
│       └── InferenceResponse  # correlation_id, response, token counts
├── Helpers/
│   ├── Rpc                # Correlation ID generation, reply headers
│   └── Auth               # JWT sign/validate via legion-crypt
├── Runners/
│   ├── Metering           # build_event, publish_or_spool, flush_spool
│   ├── Inference          # chat, embed, structured (auto-metered)
│   ├── Fleet              # dispatch to GPU workers, timeout, settings
│   ├── FleetHandler       # handle_fleet_request (JWT validate, local LLM call)
│   └── MeteringWriter     # write_metering_record (DB insert from RMQ)
├── Actors/
│   ├── InferenceWorker    # Subscription: consumes llm.inference.process
│   ├── MeteringWriter     # Subscription: consumes llm.metering.write
│   └── SpoolFlush         # Interval (60s): flushes disk spool to RMQ
└── Client                 # Standalone client with all runners
```

## Three Node Roles

| Role | What It Does | Required |
|------|-------------|----------|
| **Publisher** (all nodes) | Calls `Inference.chat` which auto-meters to RMQ or spool | lex-llm-gateway gem |
| **Fleet Worker** (GPU nodes) | Runs InferenceWorker actor, processes fleet requests | lex-llm-gateway + Legion::LLM |
| **Metering Writer** (DB nodes) | Runs MeteringWriter actor, writes to metering_records | lex-llm-gateway + Legion::Data |

## Degradation Ladder

```
Full stack (transport + gateway + LLM + fleet)
  └─ No transport → spool to disk, flush when reconnected
      └─ No gateway → Legion::LLM direct (no metering)
          └─ No fleet → local/cloud only
              └─ No cloud → local LLM only
                  └─ No local → error
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

## Integration Points

- **legion-transport**: Exchanges and queues for metering and inference RPC
- **legion-crypt**: JWT signing/validation for fleet requests
- **legion-data**: Spool for offline buffering; MeteringWriter inserts to metering_records table
- **Legion::LLM**: Inference runner wraps LLM calls; Fleet handler delegates to local LLM
- **lex-metering**: MeteringWriter writes the same metering_records that lex-metering queries

## Development

```bash
bundle install
bundle exec rspec        # 199 examples, 0 failures
bundle exec rubocop      # 0 offenses
```

## Design Doc

`docs/work/completed/2026-03-18-llm-gateway-design.md`

---

**Maintained By**: Matthew Iverson (@Esity)

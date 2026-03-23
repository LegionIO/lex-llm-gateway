# Fleet RPC wait_for_response Implementation Plan

## Phase 1: Reply Dispatcher (new file)

Create `lib/legion/extensions/llm/gateway/helpers/reply_dispatcher.rb`

- Process-singleton that manages a long-lived consumer on the agent queue
- `Concurrent::Map` of `correlation_id → Concurrent::Promises.resolvable_future`
- `register(correlation_id)` → creates and stores a future, returns it
- `deregister(correlation_id)` → removes the entry (called in ensure block)
- `handle_delivery(payload)` → matches `correlation_id`, resolves the future
- Lazy-starts the consumer on first `register` call
- Thread-safe via `Concurrent::Map` (lock-free)

## Phase 2: Fleet.wait_for_response (modify existing)

Modify `lib/legion/extensions/llm/gateway/runners/fleet.rb`

Replace the stub:

```ruby
def wait_for_response(correlation_id, timeout:)
  future = Helpers::ReplyDispatcher.register(correlation_id)
  result = future.value!(timeout)
  return result if result&.dig(:success) != false

  result || timeout_result(correlation_id, timeout)
rescue Concurrent::Promises::ResolvableFuture::TimeoutError
  timeout_result(correlation_id, timeout)
ensure
  Helpers::ReplyDispatcher.deregister(correlation_id)
end

def timeout_result(correlation_id, timeout)
  { success: false, error: 'fleet_timeout', correlation_id: correlation_id, timeout: timeout }
end
```

## Phase 3: FleetHandler reply publishing (modify existing)

Modify `lib/legion/extensions/llm/gateway/runners/fleet_handler.rb`

- After `build_response`, publish an `InferenceResponse` to the `reply_to` queue
- Use default exchange (`""`) with `routing_key: reply_to` — standard AMQP direct-to-queue

```ruby
def handle_fleet_request(payload)
  token = payload[:signed_token]
  return error_reply(payload, 'invalid_token') if require_auth? && !valid_token?(token)

  response = call_local_llm(payload)
  response_hash = build_response(payload[:correlation_id], response)
  publish_reply(payload[:reply_to], response_hash) if payload[:reply_to]
  response_hash
end

def publish_reply(reply_to, response_hash)
  channel = Legion::Transport.channel
  channel.default_exchange.publish(
    Legion::JSON.dump(response_hash),
    routing_key: reply_to,
    correlation_id: response_hash[:correlation_id],
    content_type: 'application/json'
  )
end
```

## Phase 4: Specs

### `spec/legion/extensions/llm/gateway/helpers/reply_dispatcher_spec.rb` (new)
- register returns a future
- deregister removes the entry
- handle_delivery resolves the correct future by correlation_id
- handle_delivery ignores unknown correlation_ids
- thread safety: concurrent register/deregister

### `spec/legion/extensions/llm/gateway/runners/fleet_spec.rb` (modify)
- wait_for_response returns result when future resolves
- wait_for_response returns timeout when future doesn't resolve
- deregister called in ensure (even on timeout)

### `spec/legion/extensions/llm/gateway/runners/fleet_handler_spec.rb` (modify)
- handle_fleet_request publishes reply to reply_to queue
- handle_fleet_request skips publish when reply_to is nil

## File Summary

| File | Action |
|------|--------|
| `lib/legion/extensions/llm/gateway/helpers/reply_dispatcher.rb` | Create |
| `lib/legion/extensions/llm/gateway/runners/fleet.rb` | Modify `wait_for_response` |
| `lib/legion/extensions/llm/gateway/runners/fleet_handler.rb` | Add `publish_reply` |
| `spec/.../helpers/reply_dispatcher_spec.rb` | Create |
| `spec/.../runners/fleet_spec.rb` | Modify |
| `spec/.../runners/fleet_handler_spec.rb` | Modify |

## Dependencies

- `concurrent-ruby` (already in LegionIO gemspec)
- `legion-transport` (already required by lex-llm-gateway)
- No new gem dependencies

# Fleet RPC wait_for_response Design

## Problem

`Fleet.dispatch` publishes an `InferenceRequest` to the `llm.inference` exchange with a `correlation_id` and `reply_to` queue name, then calls `wait_for_response` — which is a stub that immediately returns `{ success: false, error: 'fleet_timeout' }`. Fleet RPC is wired end-to-end (request publish, worker consumption, response building) but the caller never actually waits for the response.

## Current Flow

```
Fleet.dispatch
  ├── publish_request → InferenceRequest to llm.inference exchange
  └── wait_for_response(correlation_id, timeout:)
       └── STUB: returns { success: false, error: 'fleet_timeout' }
```

On the worker side, `InferenceWorker` (subscription actor) consumes from `llm.inference.process`, delegates to `FleetHandler.handle_fleet_request`, which calls the local LLM and builds an `InferenceResponse` — but never publishes it back. There are two gaps:

1. `FleetHandler` builds the response hash but doesn't publish an `InferenceResponse` message to the reply-to queue
2. `Fleet.wait_for_response` doesn't subscribe to or poll the reply queue

## Proposed Solution

### 1. Reply Queue Consumer

Use a `Concurrent::Promises` future with a temporary Bunny consumer on the agent queue. The agent queue (`agent.<node_name>`) already exists in legion-transport as an auto-delete, non-durable queue — perfect for ephemeral RPC replies.

```ruby
def wait_for_response(correlation_id, timeout:)
  promise = Concurrent::Promises.resolvable_future
  consumer = subscribe_for_reply(correlation_id, promise)

  result = promise.value!(timeout)
  result || { success: false, error: 'fleet_timeout', correlation_id: correlation_id, timeout: timeout }
rescue Concurrent::Promises::ResolvableFuture::TimeoutError
  { success: false, error: 'fleet_timeout', correlation_id: correlation_id, timeout: timeout }
ensure
  consumer&.cancel
end
```

### 2. Reply Publishing

`FleetHandler.handle_fleet_request` must publish the response back. It receives `reply_to` in the payload:

```ruby
def handle_fleet_request(payload)
  # ... existing JWT validation and LLM call ...
  response_hash = build_response(payload[:correlation_id], response)
  publish_reply(payload[:reply_to], payload[:correlation_id], response_hash)
  response_hash
end

def publish_reply(reply_to, correlation_id, response_hash)
  Transport::Messages::InferenceResponse.new(
    **response_hash,
    correlation_id: correlation_id
  ).publish_to(reply_to)
end
```

### 3. InferenceResponse.publish_to

The existing `Message#publish` always publishes to the message's declared exchange. We need a `publish_to(queue_name)` that publishes directly to a named queue via the default exchange (empty string exchange, routing_key = queue name). This is standard AMQP direct-reply-to pattern.

### Correlation ID Matching

Multiple fleet requests can be in-flight concurrently. The agent queue consumer must filter by `correlation_id`:

- A process-level `ConcurrentHash` maps `correlation_id → promise`
- A single long-lived consumer on the agent queue dispatches incoming messages to the matching promise
- This avoids creating a new consumer per request

### Alternatives Considered

1. **Exclusive temporary queue per request**: Simpler but creates queue churn on RabbitMQ. At scale (100+ concurrent fleet requests), this is wasteful.
2. **RabbitMQ Direct Reply-To (`amq.rabbitmq.reply-to`)**: Bunny supports this pseudo-queue, but it's per-channel and doesn't support multiple concurrent waiters on one channel. Would require a channel-per-request model.
3. **Response cache polling (legion-cache/memcached)**: Worker writes response to memcached keyed by correlation_id, caller polls. Adds a dependency and polling latency. Not chosen.

The shared agent queue with correlation dispatch is the standard AMQP RPC pattern and fits legion-transport's existing infrastructure.

## Constraints

- `concurrent-ruby` is already a dependency of LegionIO (>= 1.2)
- Agent queue is auto-delete — if the requesting node dies, the queue disappears and the worker's response is dead-lettered (acceptable)
- Timeout must be configurable (currently `fleet.timeout_seconds`, default 30)
- The long-lived consumer must be thread-safe (Bunny consumers run in their own thread)

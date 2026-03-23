# frozen_string_literal: true

require 'concurrent'

module Legion
  module Extensions
    module LLM
      module Gateway
        module Helpers
          module ReplyDispatcher
            @pending = Concurrent::Map.new
            @mutex = Mutex.new
            @consumer = nil

            module_function

            def register(correlation_id)
              future = Concurrent::Promises.resolvable_future
              @pending[correlation_id] = future
              ensure_consumer
              future
            end

            def deregister(correlation_id)
              @pending.delete(correlation_id)
            end

            def handle_delivery(raw_payload, properties = {})
              payload = parse_payload(raw_payload)
              cid = properties[:correlation_id] || payload[:correlation_id]
              return unless cid

              future = @pending.delete(cid)
              return unless future

              future.fulfill(payload.merge(success: true))
            rescue StandardError => e
              log_warn("ReplyDispatcher: handle_delivery failed: #{e.message}")
            end

            def pending_count
              @pending.size
            end

            def reset!
              @mutex.synchronize do
                cancel_consumer
                @pending = Concurrent::Map.new
              end
            end

            # private

            def ensure_consumer # rubocop:disable Metrics/MethodLength
              @mutex.synchronize do
                return if @consumer
                return unless transport_available?

                queue_name = Rpc.agent_queue_name
                return unless queue_name

                channel = Legion::Transport.connection.create_channel
                queue = channel.queue(queue_name, auto_delete: true, durable: false)
                @consumer = queue.subscribe(manual_ack: false) do |_delivery, properties, body|
                  props = { correlation_id: properties.correlation_id }
                  handle_delivery(body, props)
                end
              end
            rescue StandardError => e
              log_warn("ReplyDispatcher: consumer setup failed: #{e.message}")
            end

            def cancel_consumer
              @consumer&.cancel
              @consumer = nil
            rescue StandardError => e
              log_warn("ReplyDispatcher: cancel failed: #{e.message}")
            end

            def transport_available?
              defined?(Legion::Transport) &&
                Legion::Transport.respond_to?(:connection) &&
                Legion::Transport.connection
            end

            def parse_payload(raw)
              return raw if raw.is_a?(Hash)

              if defined?(Legion::JSON)
                Legion::JSON.load(raw)
              else
                require 'json'
                JSON.parse(raw, symbolize_names: true)
              end
            rescue StandardError
              {}
            end

            def log_warn(msg)
              Legion::Logging.warn(msg) if defined?(Legion::Logging)
            end
          end
        end
      end
    end
  end
end

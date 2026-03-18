# frozen_string_literal: true

module Legion
  module Extensions
    module LLM
      module Gateway
        module Runners
          module MeteringWriter
            module_function

            def write_metering_record(payload)
              return { success: false, error: 'data_not_connected' } unless data_connected?

              record = normalize_record(payload)
              Legion::Data.connection[:metering_records].insert(record)
              { success: true, recorded: record }
            end

            def data_connected?
              !!(defined?(Legion::Data) &&
                 Legion::Data.respond_to?(:connection) &&
                 !Legion::Data.connection.nil?)
            end

            def normalize_record(payload)
              identity_fields(payload).merge(metric_fields(payload))
            end

            def identity_fields(payload)
              {
                worker_id: payload[:worker_id],
                task_id: payload[:task_id],
                provider: payload[:provider],
                model_id: payload[:model_id],
                routing_reason: payload[:routing_reason],
                recorded_at: payload[:recorded_at] || Time.now.utc
              }
            end

            def metric_fields(payload)
              {
                input_tokens: payload[:input_tokens].to_i,
                output_tokens: payload[:output_tokens].to_i,
                thinking_tokens: payload[:thinking_tokens].to_i,
                total_tokens: payload[:total_tokens].to_i,
                latency_ms: payload[:latency_ms].to_i,
                wall_clock_ms: payload[:wall_clock_ms].to_i
              }
            end
          end
        end
      end
    end
  end
end

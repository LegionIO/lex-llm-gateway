# frozen_string_literal: true

module Legion
  module Extensions
    module LLM
      module Gateway
        module Transport
          module Messages
            class MeteringEvent < Legion::Transport::Message
              def routing_key
                "metering.#{@options[:request_type] || 'unknown'}"
              end

              def type
                'metering_event'
              end

              def encrypt?
                false
              end

              def validate
                raise 'request_type is required' unless @options[:request_type]
                raise 'provider is required' unless @options[:provider]

                @valid = true
              end

              def message
                identity_fields.merge(token_fields).merge(timing_fields).merge(context_fields)
              end

              private

              def identity_fields
                {
                  node_id: @options[:node_id],
                  worker_id: @options[:worker_id],
                  agent_id: @options[:agent_id],
                  request_type: @options[:request_type],
                  tier: @options[:tier],
                  provider: @options[:provider],
                  model_id: @options[:model_id]
                }
              end

              def context_fields
                {
                  routing_reason: @options[:routing_reason],
                  recorded_at: @options[:recorded_at] || Time.now.utc.iso8601
                }
              end

              def token_fields
                {
                  input_tokens: @options[:input_tokens] || 0,
                  output_tokens: @options[:output_tokens] || 0,
                  thinking_tokens: @options[:thinking_tokens] || 0,
                  total_tokens: @options[:total_tokens] || 0
                }
              end

              def timing_fields
                {
                  latency_ms: @options[:latency_ms] || 0,
                  wall_clock_ms: @options[:wall_clock_ms] || 0
                }
              end
            end
          end
        end
      end
    end
  end
end

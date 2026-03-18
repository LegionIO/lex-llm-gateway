# frozen_string_literal: true

module Legion
  module Extensions
    module LLM
      module Gateway
        module Transport
          module Messages
            class InferenceResponse < Legion::Transport::Message
              def routing_key
                'inference.response'
              end

              def type
                'inference_response'
              end

              def encrypt?
                false
              end

              def validate
                raise 'correlation_id is required' unless @options[:correlation_id]

                @valid = true
              end

              def message
                token_fields.merge(
                  correlation_id: @options[:correlation_id],
                  response: @options[:response],
                  provider: @options[:provider],
                  model_id: @options[:model_id],
                  error: @options[:error]
                )
              end

              private

              def token_fields
                {
                  input_tokens: @options[:input_tokens] || 0,
                  output_tokens: @options[:output_tokens] || 0,
                  thinking_tokens: @options[:thinking_tokens] || 0,
                  latency_ms: @options[:latency_ms] || 0
                }
              end
            end
          end
        end
      end
    end
  end
end

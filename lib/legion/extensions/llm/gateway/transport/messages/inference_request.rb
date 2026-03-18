# frozen_string_literal: true

module Legion
  module Extensions
    module LLM
      module Gateway
        module Transport
          module Messages
            class InferenceRequest < Legion::Transport::Message
              def routing_key
                'inference.request'
              end

              def type
                'inference_request'
              end

              def encrypt?
                false
              end

              def validate
                raise 'model is required' unless @options[:model]
                raise 'reply_to is required' unless @options[:reply_to]
                raise 'correlation_id is required' unless @options[:correlation_id]

                @valid = true
              end

              def message
                {
                  model: @options[:model],
                  messages: @options[:messages] || [],
                  intent: @options[:intent],
                  reply_to: @options[:reply_to],
                  correlation_id: @options[:correlation_id],
                  signed_token: @options[:signed_token],
                  provider: @options[:provider],
                  tier: @options[:tier]
                }
              end
            end
          end
        end
      end
    end
  end
end

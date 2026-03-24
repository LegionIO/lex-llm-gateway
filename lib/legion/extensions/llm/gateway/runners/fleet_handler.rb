# frozen_string_literal: true

module Legion
  module Extensions
    module LLM
      module Gateway
        module Runners
          module FleetHandler
            module_function

            def handle_fleet_request(payload)
              token = payload[:signed_token]
              if require_auth? && !valid_token?(token)
                error_response = { success: false, error: 'invalid_token' }
                publish_reply(payload[:reply_to], payload[:correlation_id], error_response) if payload[:reply_to]
                return error_response
              end

              response = call_local_llm(payload)
              response_hash = build_response(payload[:correlation_id], response)
              publish_reply(payload[:reply_to], payload[:correlation_id], response_hash) if payload[:reply_to]
              response_hash
            end

            def require_auth?
              Fleet.require_auth?
            end

            def valid_token?(token)
              return true if token.nil? && !require_auth?

              !Helpers::Auth.validate_token(token).nil?
            end

            def call_local_llm(payload)
              return { error: 'llm_not_available' } unless defined?(Legion::LLM)

              case payload[:request_type]&.to_s
              when 'structured'
                call_structured(payload)
              when 'embed'
                call_embed(payload)
              else
                call_chat(payload)
              end
            end

            def call_chat(payload)
              messages = payload[:messages]
              if messages.is_a?(Array) && messages.size > 1
                Legion::LLM.chat(model: payload[:model], messages: messages,
                                 caller: { extension: 'lex-llm-gateway', operation: 'fleet' })
              else
                Legion::LLM.chat(model: payload[:model], message: messages&.dig(0, :content),
                                 caller: { extension: 'lex-llm-gateway', operation: 'fleet' })
              end
            end

            def call_structured(payload)
              Legion::LLM.structured(
                model: payload[:model],
                messages: payload[:messages],
                schema: payload[:schema],
                caller: { extension: 'lex-llm-gateway', operation: 'fleet' }
              )
            end

            def call_embed(payload)
              text = payload[:text] || payload.dig(:messages, 0, :content)
              Legion::LLM.embed(model: payload[:model], text: text,
                                caller: { extension: 'lex-llm-gateway', operation: 'fleet' })
            end

            def build_response(correlation_id, response)
              {
                correlation_id: correlation_id,
                response: response,
                input_tokens: extract_token(response, :input_tokens),
                output_tokens: extract_token(response, :output_tokens),
                thinking_tokens: extract_token(response, :thinking_tokens),
                provider: extract_field(response, :provider),
                model_id: extract_field(response, :model)
              }
            end

            def publish_reply(reply_to, correlation_id, response_hash) # rubocop:disable Metrics/MethodLength
              return unless defined?(Legion::Transport)

              payload = if defined?(Legion::JSON)
                          Legion::JSON.dump(response_hash)
                        else
                          require 'json'
                          JSON.generate(response_hash)
                        end

              channel = Legion::Transport.connection.create_channel
              channel.default_exchange.publish(
                payload,
                routing_key: reply_to,
                correlation_id: correlation_id,
                content_type: 'application/json'
              )
              channel.close
            rescue StandardError => e
              log_warn("FleetHandler: publish_reply failed: #{e.message}")
            end

            def log_warn(msg)
              Legion::Logging.warn(msg) if defined?(Legion::Logging)
            end

            def extract_token(response, field)
              return 0 unless response.respond_to?(field)

              response.public_send(field).to_i
            end

            def extract_field(response, field)
              return nil unless response.respond_to?(field)

              response.public_send(field)
            end
          end
        end
      end
    end
  end
end

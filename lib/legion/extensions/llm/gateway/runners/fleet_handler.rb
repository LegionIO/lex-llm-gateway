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
              return { success: false, error: 'invalid_token' } if require_auth? && !valid_token?(token)

              response = call_local_llm(payload)
              build_response(payload[:correlation_id], response)
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

              Legion::LLM.chat(
                model: payload[:model],
                message: payload.dig(:messages, 0, :content)
              )
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

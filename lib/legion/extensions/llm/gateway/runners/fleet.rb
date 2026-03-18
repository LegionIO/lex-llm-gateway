# frozen_string_literal: true

module Legion
  module Extensions
    module LLM
      module Gateway
        module Runners
          module Fleet
            DEFAULT_TIMEOUT = 30

            module_function

            def dispatch(model:, messages:, intent: nil, timeout: nil)
              return error_result('fleet_unavailable') unless fleet_available?

              token = Helpers::Auth.sign_request({ model: model, intent: intent })
              return error_result('fleet_auth_failed') if token.nil? && require_auth?

              correlation_id = Helpers::Rpc.generate_correlation_id
              publish_request(model: model, messages: messages, intent: intent,
                              correlation_id: correlation_id, signed_token: token)

              wait_for_response(correlation_id, timeout: resolve_timeout(timeout))
            end

            def fleet_available?
              transport_ready? && fleet_enabled?
            end

            def transport_ready?
              !!(defined?(Legion::Transport) &&
                 Legion::Transport.respond_to?(:connected?) &&
                 Legion::Transport.connected?)
            end

            def fleet_enabled?
              return true unless defined?(Legion::Settings)

              settings = Legion::Settings[:llm] rescue nil # rubocop:disable Style/RescueModifier
              return true unless settings.is_a?(Hash)

              routing = settings[:routing]
              return true unless routing.is_a?(Hash)

              routing.fetch(:use_fleet, true)
            end

            def require_auth?
              return false unless defined?(Legion::Settings)

              settings = Legion::Settings[:llm] rescue nil # rubocop:disable Style/RescueModifier
              return false unless settings.is_a?(Hash)

              fleet = settings.dig(:routing, :fleet)
              return false unless fleet.is_a?(Hash)

              fleet.fetch(:require_auth, false)
            end

            def resolve_timeout(override)
              return override if override

              return DEFAULT_TIMEOUT unless defined?(Legion::Settings)

              settings = Legion::Settings[:llm] rescue nil # rubocop:disable Style/RescueModifier
              return DEFAULT_TIMEOUT unless settings.is_a?(Hash)

              settings.dig(:routing, :fleet, :timeout_seconds) || DEFAULT_TIMEOUT
            end

            def publish_request(model:, messages:, intent:, correlation_id:, signed_token:)
              reply_to = Helpers::Rpc.agent_queue_name
              Transport::Messages::InferenceRequest.new(
                model: model, messages: messages, intent: intent,
                reply_to: reply_to, correlation_id: correlation_id,
                signed_token: signed_token
              ).publish
            end

            def wait_for_response(correlation_id, timeout:)
              { success: false, error: 'fleet_timeout', correlation_id: correlation_id, timeout: timeout }
            end

            def error_result(reason)
              { success: false, error: reason }
            end
          end
        end
      end
    end
  end
end

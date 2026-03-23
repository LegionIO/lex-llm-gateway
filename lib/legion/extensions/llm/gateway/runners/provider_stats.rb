# frozen_string_literal: true

module Legion
  module Extensions
    module LLM
      module Gateway
        module Runners
          module ProviderStats
            module_function

            def health_report
              return unavailable_result unless router_available?

              tracker = health_tracker
              providers = known_providers
              providers.map { |name| provider_entry(name, tracker) }
            end

            def provider_detail(provider:)
              return unavailable_result unless router_available?

              provider_entry(provider, health_tracker)
            end

            def circuit_summary
              return unavailable_result unless router_available?

              tracker = health_tracker
              providers = known_providers
              {
                total: providers.size,
                closed: providers.count { |p| tracker.circuit_state(p) == :closed },
                open: providers.count { |p| tracker.circuit_state(p) == :open },
                half_open: providers.count { |p| tracker.circuit_state(p) == :half_open }
              }
            end

            def router_available?
              defined?(Legion::LLM::Router) &&
                Legion::LLM::Router.respond_to?(:routing_enabled?) &&
                Legion::LLM::Router.routing_enabled?
            end

            def health_tracker
              Legion::LLM::Router.health_tracker
            end

            def known_providers
              return [] unless defined?(Legion::Settings)

              providers = Legion::Settings.dig(:llm, :providers)
              return [] unless providers.is_a?(Hash)

              providers.select { |_, cfg| cfg.is_a?(Hash) && cfg[:enabled] }
                       .keys
                       .map(&:to_sym)
            rescue StandardError
              []
            end

            def provider_entry(name, tracker)
              {
                provider: name.to_s,
                circuit: tracker.circuit_state(name).to_s,
                adjustment: tracker.adjustment(name),
                healthy: tracker.circuit_state(name) != :open
              }
            end

            def unavailable_result
              { success: false, error: 'router_not_available' }
            end
          end
        end
      end
    end
  end
end

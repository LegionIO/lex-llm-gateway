# frozen_string_literal: true

require_relative 'runners/inference'
require_relative 'runners/metering'
require_relative 'runners/fleet'

module Legion
  module Extensions
    module LLM
      module Gateway
        class Client
          def initialize(**opts)
            @opts = opts
          end

          def settings
            { options: @opts }
          end

          def chat(**)
            Runners::Inference.chat(**)
          end

          def embed(**)
            Runners::Inference.embed(**)
          end

          def structured(**)
            Runners::Inference.structured(**)
          end

          def build_event(**)
            Runners::Metering.build_event(**)
          end

          def publish_or_spool(event)
            Runners::Metering.publish_or_spool(event)
          end

          def flush_spool
            Runners::Metering.flush_spool
          end

          def dispatch(**)
            Runners::Fleet.dispatch(**)
          end

          def fleet_available?
            Runners::Fleet.fleet_available?
          end
        end
      end
    end
  end
end

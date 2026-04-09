# frozen_string_literal: true

module Legion
  module Extensions
    module Llm
      module Gateway
        module Actor
          class InferenceWorker < Legion::Extensions::Actors::Subscription
            def runner_class
              'Legion::Extensions::Llm::Gateway::Runners::FleetHandler'
            end

            def runner_function
              'handle_fleet_request'
            end

            def use_runner?
              false
            end
          end
        end
      end
    end
  end
end

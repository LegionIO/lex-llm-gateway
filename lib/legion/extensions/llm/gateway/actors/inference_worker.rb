# frozen_string_literal: true

module Legion
  module Extensions
    module LLM
      module Gateway
        module Actor
          class InferenceWorker < Legion::Extensions::Actors::Subscription
            def runner_class
              'Legion::Extensions::LLM::Gateway::Runners::Inference'
            end

            def runner_function
              'handle_fleet_request'
            end
          end
        end
      end
    end
  end
end

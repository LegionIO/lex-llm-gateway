# frozen_string_literal: true

module Legion
  module Extensions
    module LLM
      module Gateway
        module Actor
          class MeteringWriter < Legion::Extensions::Actors::Subscription
            def runner_class
              'Legion::Extensions::LLM::Gateway::Runners::MeteringWriter'
            end

            def runner_function
              'write_metering_record'
            end
          end
        end
      end
    end
  end
end

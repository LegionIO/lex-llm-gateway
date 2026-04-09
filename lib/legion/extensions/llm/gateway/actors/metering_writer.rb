# frozen_string_literal: true

module Legion
  module Extensions
    module Llm
      module Gateway
        module Actor
          class MeteringWriter < Legion::Extensions::Actors::Subscription
            def runner_class
              'Legion::Extensions::Llm::Gateway::Runners::MeteringWriter'
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

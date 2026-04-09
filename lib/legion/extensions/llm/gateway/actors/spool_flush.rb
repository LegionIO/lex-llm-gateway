# frozen_string_literal: true

module Legion
  module Extensions
    module Llm
      module Gateway
        module Actor
          class SpoolFlush < Legion::Extensions::Actors::Every # rubocop:disable Legion/Extension/EveryActorRequiresTime
            def runner_class
              'Legion::Extensions::Llm::Gateway::Runners::Metering'
            end

            def runner_function
              'flush_spool'
            end

            def time
              60
            end

            def run_now?
              false
            end

            def use_runner?
              false
            end

            def check_subtask?
              false
            end

            def generate_task?
              false
            end
          end
        end
      end
    end
  end
end

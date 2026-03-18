# frozen_string_literal: true

module Legion
  module Extensions
    module LLM
      module Gateway
        module Transport
          module Queues
            class InferenceProcess < Legion::Transport::Queue
              def queue_name
                'llm.inference.process'
              end

              def queue_options
                {
                  durable: true,
                  auto_delete: false
                }
              end
            end
          end
        end
      end
    end
  end
end

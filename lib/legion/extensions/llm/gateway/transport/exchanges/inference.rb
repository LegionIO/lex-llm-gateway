# frozen_string_literal: true

module Legion
  module Extensions
    module LLM
      module Gateway
        module Transport
          module Exchanges
            class Inference < Legion::Transport::Exchange
              def exchange_name
                'llm.inference'
              end

              def exchange_type
                :direct
              end
            end
          end
        end
      end
    end
  end
end

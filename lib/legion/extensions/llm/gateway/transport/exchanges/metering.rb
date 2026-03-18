# frozen_string_literal: true

module Legion
  module Extensions
    module LLM
      module Gateway
        module Transport
          module Exchanges
            class Metering < Legion::Transport::Exchange
              def exchange_name
                'llm.metering'
              end

              def exchange_type
                :topic
              end
            end
          end
        end
      end
    end
  end
end

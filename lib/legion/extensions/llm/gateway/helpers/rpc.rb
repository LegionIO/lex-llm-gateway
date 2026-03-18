# frozen_string_literal: true

require 'securerandom'

module Legion
  module Extensions
    module LLM
      module Gateway
        module Helpers
          module Rpc
            module_function

            def generate_correlation_id
              SecureRandom.uuid
            end

            def agent_queue_name
              if defined?(Legion::Transport) && Legion::Transport.respond_to?(:agent_queue_name)
                return Legion::Transport.agent_queue_name
              end

              nil
            end

            def build_reply_headers(correlation_id:)
              {
                reply_to: agent_queue_name,
                correlation_id: correlation_id
              }
            end
          end
        end
      end
    end
  end
end

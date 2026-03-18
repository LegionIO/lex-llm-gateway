# frozen_string_literal: true

module Legion
  module Extensions
    module LLM
      module Gateway
        module Helpers
          module Auth
            module_function

            def sign_request(payload)
              return nil unless defined?(Legion::Crypt::JWT)

              Legion::Crypt::JWT.encode(payload: payload, ttl: 60)
            rescue StandardError
              nil
            end

            def validate_token(token)
              return nil unless defined?(Legion::Crypt::JWT)

              Legion::Crypt::JWT.decode(token: token)
            rescue StandardError
              nil
            end
          end
        end
      end
    end
  end
end

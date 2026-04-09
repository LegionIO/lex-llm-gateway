# frozen_string_literal: true

require 'legion/extensions/llm/gateway/version'

module Legion
  module Extensions
    module Llm
      module Gateway
        extend Legion::Extensions::Core if Legion::Extensions.const_defined?(:Core, false)
      end
    end
  end
end

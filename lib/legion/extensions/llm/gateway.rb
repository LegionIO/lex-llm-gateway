# frozen_string_literal: true

require 'legion/extensions/llm/gateway/version'

module Legion
  module Extensions
    module LLM
      module Gateway
        extend Legion::Extensions::Core if Legion::Extensions.const_defined?(:Core)
      end
    end
    remove_const(:Llm) if const_defined?(:Llm, false)
    Llm = LLM
  end
end

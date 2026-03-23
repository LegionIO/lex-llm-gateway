# frozen_string_literal: true

require 'legion/extensions/llm/gateway'

RSpec.describe Legion::Extensions::LLM::Gateway do
  it 'has a version number' do
    expect(Legion::Extensions::LLM::Gateway::VERSION).not_to be_nil
  end

  it 'version is 0.2.9' do
    expect(Legion::Extensions::LLM::Gateway::VERSION).to eq('0.2.9')
  end
end

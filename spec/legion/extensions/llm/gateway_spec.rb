# frozen_string_literal: true

require 'legion/extensions/llm/gateway'

RSpec.describe Legion::Extensions::Llm::Gateway do
  it 'has a version number' do
    expect(Legion::Extensions::Llm::Gateway::VERSION).not_to be_nil
  end

  it 'version is 0.2.13' do
    expect(Legion::Extensions::Llm::Gateway::VERSION).to eq('0.2.13')
  end
end

# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/llm/gateway/runners/metering'
require 'legion/extensions/llm/gateway/runners/fleet'
require 'legion/extensions/llm/gateway/runners/inference'
require 'legion/extensions/llm/gateway/client'

RSpec.describe Legion::Extensions::LLM::Gateway::Client do
  subject(:client) { described_class.new }

  let(:response_double) do
    double('response',
           input_tokens: 100,
           output_tokens: 50,
           thinking_tokens: 0,
           provider: 'anthropic',
           model: 'claude-opus-4-6')
  end

  describe '#initialize' do
    it 'creates an instance with no opts' do
      expect(client).to be_a(described_class)
    end

    it 'stores provided opts' do
      c = described_class.new(timeout: 30)
      expect(c.settings).to eq({ options: { timeout: 30 } })
    end
  end

  describe '#settings' do
    it 'returns a hash with an options key' do
      expect(client.settings).to be_a(Hash)
      expect(client.settings).to have_key(:options)
    end

    it 'returns empty options when constructed with no args' do
      expect(client.settings[:options]).to eq({})
    end
  end

  describe 'Inference runner methods' do
    it { is_expected.to respond_to(:chat) }
    it { is_expected.to respond_to(:embed) }
    it { is_expected.to respond_to(:structured) }
  end

  describe 'Metering runner methods' do
    it { is_expected.to respond_to(:build_event) }
    it { is_expected.to respond_to(:publish_or_spool) }
    it { is_expected.to respond_to(:flush_spool) }
  end

  describe 'Fleet runner methods' do
    it { is_expected.to respond_to(:dispatch) }
    it { is_expected.to respond_to(:fleet_available?) }
  end

  describe '#chat delegation' do
    before do
      stub_const('Legion::LLM', double('LLM'))
      allow(Legion::LLM).to receive(:chat).and_return(response_double)
      allow(Legion::Extensions::LLM::Gateway::Runners::Metering).to receive(:build_event).and_return({})
      allow(Legion::Extensions::LLM::Gateway::Runners::Metering).to receive(:publish_or_spool)
    end

    it 'delegates chat to Inference runner' do
      result = client.chat(message: 'hello', model: 'test')
      expect(result).to eq(response_double)
    end

    it 'calls Legion::LLM.chat' do
      client.chat(message: 'hello', model: 'test')
      expect(Legion::LLM).to have_received(:chat)
    end
  end
end

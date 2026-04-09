# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/llm/gateway/runners/provider_stats'

RSpec.describe Legion::Extensions::Llm::Gateway::Runners::ProviderStats do
  let(:tracker) do
    instance_double('HealthTracker',
                    circuit_state: :closed,
                    adjustment:    0)
  end

  before do
    allow(described_class).to receive(:router_available?).and_return(true)
    allow(described_class).to receive(:health_tracker).and_return(tracker)
    allow(described_class).to receive(:known_providers).and_return(%i[anthropic openai ollama])
  end

  describe '.health_report' do
    it 'returns an entry for each provider' do
      result = described_class.health_report
      expect(result.size).to eq(3)
      expect(result.first[:provider]).to eq('anthropic')
      expect(result.first[:circuit]).to eq('closed')
      expect(result.first[:healthy]).to be true
    end

    it 'returns unavailable when router not ready' do
      allow(described_class).to receive(:router_available?).and_return(false)
      result = described_class.health_report
      expect(result[:error]).to eq('router_not_available')
    end
  end

  describe '.provider_detail' do
    it 'returns detail for a single provider' do
      result = described_class.provider_detail(provider: :anthropic)
      expect(result[:provider]).to eq('anthropic')
      expect(result[:adjustment]).to eq(0)
    end
  end

  describe '.circuit_summary' do
    it 'counts circuits by state' do
      allow(tracker).to receive(:circuit_state).with(:anthropic).and_return(:closed)
      allow(tracker).to receive(:circuit_state).with(:openai).and_return(:open)
      allow(tracker).to receive(:circuit_state).with(:ollama).and_return(:half_open)

      result = described_class.circuit_summary
      expect(result[:total]).to eq(3)
      expect(result[:closed]).to eq(1)
      expect(result[:open]).to eq(1)
      expect(result[:half_open]).to eq(1)
    end
  end

  describe '.known_providers' do
    it 'returns empty when settings unavailable' do
      allow(described_class).to receive(:known_providers).and_call_original
      hide_const('Legion::Settings')
      expect(described_class.known_providers).to eq([])
    end
  end
end

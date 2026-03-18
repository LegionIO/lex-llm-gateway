# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/llm/gateway/runners/metering'
require 'legion/extensions/llm/gateway/runners/inference'

RSpec.describe Legion::Extensions::LLM::Gateway::Runners::Inference do
  let(:response) do
    double('response',
           input_tokens: 100,
           output_tokens: 50,
           thinking_tokens: 10,
           provider: 'anthropic',
           model: 'claude-opus-4-6')
  end

  before do
    stub_const('Legion::LLM', double('LLM'))
    allow(Legion::LLM).to receive(:chat).and_return(response)
    allow(Legion::LLM).to receive(:embed).and_return(response)
    allow(Legion::LLM).to receive(:structured).and_return(response)

    allow(Legion::Extensions::LLM::Gateway::Runners::Metering).to receive(:build_event).and_return({})
    allow(Legion::Extensions::LLM::Gateway::Runners::Metering).to receive(:publish_or_spool)
  end

  describe '.chat' do
    it 'calls Legion::LLM.chat when tier is not fleet' do
      described_class.chat(message: 'hello', model: 'claude-opus-4-6', provider: 'anthropic')
      expect(Legion::LLM).to have_received(:chat)
    end

    it 'returns the response from Legion::LLM' do
      result = described_class.chat(message: 'hello', model: 'claude-opus-4-6', provider: 'anthropic')
      expect(result).to eq(response)
    end

    it 'calls Metering.publish_or_spool with a metering event' do
      described_class.chat(message: 'hello', model: 'claude-opus-4-6', provider: 'anthropic')
      expect(Legion::Extensions::LLM::Gateway::Runners::Metering).to have_received(:publish_or_spool)
    end

    it 'calls Metering.build_event with request_type chat' do
      described_class.chat(message: 'hello', model: 'claude-opus-4-6', provider: 'anthropic')
      expect(Legion::Extensions::LLM::Gateway::Runners::Metering)
        .to have_received(:build_event).with(hash_including(request_type: 'chat'))
    end

    context 'when tier is fleet and fleet is available' do
      let(:fleet_double) { double('Fleet', fleet_available?: true) }

      before do
        stub_const('Legion::Extensions::LLM::Gateway::Runners::Fleet', fleet_double)
        allow(fleet_double).to receive(:dispatch).and_return(response)
      end

      it 'dispatches to Fleet' do
        described_class.chat(message: 'hello', model: 'claude-opus-4-6', tier: 'fleet')
        expect(fleet_double).to have_received(:dispatch)
      end

      it 'does not call Legion::LLM.chat' do
        described_class.chat(message: 'hello', model: 'claude-opus-4-6', tier: 'fleet')
        expect(Legion::LLM).not_to have_received(:chat)
      end
    end

    context 'when Legion::LLM is not defined' do
      before { hide_const('Legion::LLM') }

      it 'returns an error hash' do
        result = described_class.chat(message: 'hello')
        expect(result).to eq({ error: 'llm_not_available' })
      end
    end
  end

  describe '.embed' do
    it 'calls Legion::LLM.embed' do
      described_class.embed(text: 'some text', model: 'embed-model', provider: 'openai')
      expect(Legion::LLM).to have_received(:embed)
    end

    it 'returns the response' do
      result = described_class.embed(text: 'some text', model: 'embed-model', provider: 'openai')
      expect(result).to eq(response)
    end

    it 'meters the call via publish_or_spool' do
      described_class.embed(text: 'some text', model: 'embed-model', provider: 'openai')
      expect(Legion::Extensions::LLM::Gateway::Runners::Metering).to have_received(:publish_or_spool)
    end

    it 'calls Metering.build_event with request_type embed' do
      described_class.embed(text: 'some text', model: 'embed-model', provider: 'openai')
      expect(Legion::Extensions::LLM::Gateway::Runners::Metering)
        .to have_received(:build_event).with(hash_including(request_type: 'embed'))
    end
  end

  describe '.structured' do
    let(:messages) { [{ role: 'user', content: 'parse this' }] }
    let(:schema) { { type: 'object' } }

    it 'calls Legion::LLM.structured' do
      described_class.structured(messages: messages, schema: schema, model: 'claude-opus-4-6')
      expect(Legion::LLM).to have_received(:structured)
    end

    it 'returns the response' do
      result = described_class.structured(messages: messages, schema: schema, model: 'claude-opus-4-6')
      expect(result).to eq(response)
    end

    it 'meters the call via publish_or_spool' do
      described_class.structured(messages: messages, schema: schema, model: 'claude-opus-4-6')
      expect(Legion::Extensions::LLM::Gateway::Runners::Metering).to have_received(:publish_or_spool)
    end

    it 'calls Metering.build_event with request_type structured' do
      described_class.structured(messages: messages, schema: schema, model: 'claude-opus-4-6')
      expect(Legion::Extensions::LLM::Gateway::Runners::Metering)
        .to have_received(:build_event).with(hash_including(request_type: 'structured'))
    end
  end

  describe '.extract_tokens' do
    it 'returns the token value when response responds to the field' do
      expect(described_class.extract_tokens(response, :input_tokens)).to eq(100)
    end

    it 'returns 0 when response does not respond to the field' do
      plain = double('plain_response')
      expect(described_class.extract_tokens(plain, :input_tokens)).to eq(0)
    end

    it 'returns 0 for nil token values' do
      nil_response = double('nil_response', input_tokens: nil)
      expect(described_class.extract_tokens(nil_response, :input_tokens)).to eq(0)
    end
  end

  describe '.meter_response' do
    it 'calls Metering.build_event with correct params' do
      described_class.meter_response(
        response,
        request_type: 'chat',
        provider: 'anthropic',
        model_id: 'claude-opus-4-6',
        latency_ms: 250,
        tier: 'cloud',
        intent: 'summarize'
      )
      expect(Legion::Extensions::LLM::Gateway::Runners::Metering).to have_received(:build_event).with(
        hash_including(
          request_type: 'chat',
          provider: 'anthropic',
          model_id: 'claude-opus-4-6',
          input_tokens: 100,
          output_tokens: 50,
          thinking_tokens: 10,
          latency_ms: 250,
          tier: 'cloud',
          routing_reason: 'summarize'
        )
      )
    end

    it 'calls Metering.publish_or_spool with the event' do
      metering_event = { request_type: 'chat', provider: 'anthropic' }
      allow(Legion::Extensions::LLM::Gateway::Runners::Metering)
        .to receive(:build_event).and_return(metering_event)

      described_class.meter_response(response, request_type: 'chat', provider: 'anthropic',
                                               model_id: nil, latency_ms: 100)
      expect(Legion::Extensions::LLM::Gateway::Runners::Metering)
        .to have_received(:publish_or_spool).with(metering_event)
    end
  end

  describe '.extract_provider' do
    it 'returns response.provider when response responds to :provider' do
      expect(described_class.extract_provider(response, 'fallback')).to eq('anthropic')
    end

    it 'returns the fallback when response does not respond to :provider' do
      plain = double('plain')
      expect(described_class.extract_provider(plain, 'fallback')).to eq('fallback')
    end
  end

  describe '.extract_model' do
    it 'returns response.model when response responds to :model' do
      expect(described_class.extract_model(response, 'fallback')).to eq('claude-opus-4-6')
    end

    it 'returns the fallback when response does not respond to :model' do
      plain = double('plain')
      expect(described_class.extract_model(plain, 'fallback')).to eq('fallback')
    end
  end
end

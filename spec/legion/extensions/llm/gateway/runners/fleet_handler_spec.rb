# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/llm/gateway/helpers/auth'
require 'legion/extensions/llm/gateway/runners/fleet_handler'

RSpec.describe Legion::Extensions::LLM::Gateway::Runners::FleetHandler do
  let(:auth_helper) { Legion::Extensions::LLM::Gateway::Helpers::Auth }

  describe '.handle_fleet_request' do
    let(:payload) do
      {
        signed_token: 'valid.jwt.token',
        correlation_id: 'corr-123',
        model: 'claude-opus-4-6',
        messages: [{ role: 'user', content: 'Hello' }]
      }
    end

    let(:llm_response) do
      double('response',
             input_tokens: 10,
             output_tokens: 20,
             thinking_tokens: 0,
             provider: 'anthropic',
             model: 'claude-opus-4-6')
    end

    before do
      allow(described_class).to receive(:require_auth?).and_return(false)
      stub_const('Legion::LLM', double('LLM'))
      allow(Legion::LLM).to receive(:chat).and_return(llm_response)
    end

    context 'when auth is required and token is valid' do
      before do
        allow(described_class).to receive(:require_auth?).and_return(true)
        allow(auth_helper).to receive(:validate_token).with('valid.jwt.token').and_return({ sub: 'worker-1' })
      end

      it 'returns a response hash' do
        result = described_class.handle_fleet_request(payload)
        expect(result).to include(:correlation_id, :response)
      end
    end

    context 'when auth is required and token is invalid' do
      before do
        allow(described_class).to receive(:require_auth?).and_return(true)
        allow(auth_helper).to receive(:validate_token).and_return(nil)
      end

      it 'returns success: false with invalid_token error' do
        result = described_class.handle_fleet_request(payload)
        expect(result).to eq({ success: false, error: 'invalid_token' })
      end
    end

    context 'when auth is not required' do
      it 'does not check the token' do
        expect(auth_helper).not_to receive(:validate_token)
        described_class.handle_fleet_request(payload)
      end

      it 'calls Legion::LLM.chat with model and message content' do
        described_class.handle_fleet_request(payload)
        expect(Legion::LLM).to have_received(:chat).with(
          model: 'claude-opus-4-6',
          message: 'Hello'
        )
      end

      it 'returns a hash with the correlation_id' do
        result = described_class.handle_fleet_request(payload)
        expect(result[:correlation_id]).to eq('corr-123')
      end

      it 'includes token counts from the response' do
        result = described_class.handle_fleet_request(payload)
        expect(result[:input_tokens]).to eq(10)
        expect(result[:output_tokens]).to eq(20)
        expect(result[:thinking_tokens]).to eq(0)
      end

      it 'includes provider and model_id from the response' do
        result = described_class.handle_fleet_request(payload)
        expect(result[:provider]).to eq('anthropic')
        expect(result[:model_id]).to eq('claude-opus-4-6')
      end
    end

    context 'when Legion::LLM is not defined' do
      before { hide_const('Legion::LLM') }

      it 'returns error hash inside response' do
        result = described_class.handle_fleet_request(payload)
        expect(result[:response]).to eq({ error: 'llm_not_available' })
      end
    end
  end

  describe '.valid_token?' do
    context 'when auth is not required and token is nil' do
      before { allow(described_class).to receive(:require_auth?).and_return(false) }

      it 'returns true' do
        expect(described_class.valid_token?(nil)).to be(true)
      end
    end

    context 'when auth is required and validate_token returns a payload' do
      before do
        allow(described_class).to receive(:require_auth?).and_return(true)
        allow(auth_helper).to receive(:validate_token).and_return({ sub: 'worker-1' })
      end

      it 'returns true' do
        expect(described_class.valid_token?('some.token')).to be(true)
      end
    end

    context 'when auth is required and validate_token returns nil' do
      before do
        allow(described_class).to receive(:require_auth?).and_return(true)
        allow(auth_helper).to receive(:validate_token).and_return(nil)
      end

      it 'returns false' do
        expect(described_class.valid_token?('bad.token')).to be(false)
      end
    end
  end

  describe '.build_response' do
    let(:response) do
      double('response',
             input_tokens: 5,
             output_tokens: 15,
             thinking_tokens: 2,
             provider: 'openai',
             model: 'gpt-4o')
    end

    it 'includes all expected keys' do
      result = described_class.build_response('cid-abc', response)
      expect(result.keys).to match_array(
        %i[correlation_id response input_tokens output_tokens thinking_tokens provider model_id]
      )
    end

    it 'sets correlation_id' do
      expect(described_class.build_response('cid-abc', response)[:correlation_id]).to eq('cid-abc')
    end

    it 'defaults token fields to 0 for plain objects' do
      plain = Object.new
      result = described_class.build_response('x', plain)
      expect(result[:input_tokens]).to eq(0)
      expect(result[:output_tokens]).to eq(0)
      expect(result[:thinking_tokens]).to eq(0)
    end

    it 'defaults provider and model_id to nil for plain objects' do
      plain = Object.new
      result = described_class.build_response('x', plain)
      expect(result[:provider]).to be_nil
      expect(result[:model_id]).to be_nil
    end
  end
end

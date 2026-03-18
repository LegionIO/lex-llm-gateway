# frozen_string_literal: true

require 'spec_helper'

unless defined?(Legion::Transport::Message)
  module Legion
    module Transport
      class Message
        def initialize(**opts)
          @options = opts
        end
      end
    end
  end
end

require 'legion/extensions/llm/gateway/transport/messages/inference_response'

RSpec.describe Legion::Extensions::LLM::Gateway::Transport::Messages::InferenceResponse do
  let(:valid_opts) { { correlation_id: 'abc-123' } }

  subject(:msg) { described_class.new(**valid_opts) }

  describe '#routing_key' do
    it 'returns inference.response' do
      expect(msg.routing_key).to eq('inference.response')
    end
  end

  describe '#type' do
    it 'returns inference_response' do
      expect(msg.type).to eq('inference_response')
    end
  end

  describe '#encrypt?' do
    it 'returns false' do
      expect(msg.encrypt?).to be(false)
    end
  end

  describe '#validate' do
    it 'raises when correlation_id is missing' do
      m = described_class.new
      expect { m.validate }.to raise_error('correlation_id is required')
    end

    it 'sets @valid to true when correlation_id is present' do
      msg.validate
      expect(msg.instance_variable_get(:@valid)).to be(true)
    end
  end

  describe '#message' do
    it 'returns a hash with all expected keys' do
      result = msg.message
      expected_keys = %i[
        correlation_id response input_tokens output_tokens
        thinking_tokens latency_ms provider model_id error
      ]
      expect(result.keys).to match_array(expected_keys)
    end

    it 'defaults input_tokens to 0' do
      expect(msg.message[:input_tokens]).to eq(0)
    end

    it 'defaults output_tokens to 0' do
      expect(msg.message[:output_tokens]).to eq(0)
    end

    it 'defaults thinking_tokens to 0' do
      expect(msg.message[:thinking_tokens]).to eq(0)
    end

    it 'defaults latency_ms to 0' do
      expect(msg.message[:latency_ms]).to eq(0)
    end

    it 'includes correlation_id from options' do
      expect(msg.message[:correlation_id]).to eq('abc-123')
    end

    it 'sets optional fields to nil when not provided' do
      expect(msg.message[:response]).to be_nil
      expect(msg.message[:provider]).to be_nil
      expect(msg.message[:model_id]).to be_nil
      expect(msg.message[:error]).to be_nil
    end

    it 'includes response when provided' do
      m = described_class.new(**valid_opts, response: 'Hello!')
      expect(m.message[:response]).to eq('Hello!')
    end
  end
end

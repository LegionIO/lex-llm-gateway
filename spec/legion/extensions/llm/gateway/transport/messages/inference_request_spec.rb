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

require 'legion/extensions/llm/gateway/transport/messages/inference_request'

RSpec.describe Legion::Extensions::LLM::Gateway::Transport::Messages::InferenceRequest do
  let(:valid_opts) do
    { model: 'gpt-4o', reply_to: 'agent.queue', correlation_id: 'abc-123' }
  end

  subject(:msg) { described_class.new(**valid_opts) }

  describe '#routing_key' do
    it 'returns inference.request' do
      expect(msg.routing_key).to eq('inference.request')
    end
  end

  describe '#type' do
    it 'returns inference_request' do
      expect(msg.type).to eq('inference_request')
    end
  end

  describe '#encrypt?' do
    it 'returns false' do
      expect(msg.encrypt?).to be(false)
    end
  end

  describe '#validate' do
    it 'raises when model is missing' do
      m = described_class.new(reply_to: 'queue', correlation_id: 'id')
      expect { m.validate }.to raise_error('model is required')
    end

    it 'raises when reply_to is missing' do
      m = described_class.new(model: 'gpt-4o', correlation_id: 'id')
      expect { m.validate }.to raise_error('reply_to is required')
    end

    it 'raises when correlation_id is missing' do
      m = described_class.new(model: 'gpt-4o', reply_to: 'queue')
      expect { m.validate }.to raise_error('correlation_id is required')
    end

    it 'sets @valid to true when all required fields are present' do
      msg.validate
      expect(msg.instance_variable_get(:@valid)).to be(true)
    end
  end

  describe '#message' do
    it 'returns a hash with all expected keys' do
      result = msg.message
      expected_keys = %i[model messages intent reply_to correlation_id signed_token provider tier]
      expect(result.keys).to match_array(expected_keys)
    end

    it 'defaults messages to an empty array' do
      expect(msg.message[:messages]).to eq([])
    end

    it 'uses provided messages' do
      m = described_class.new(**valid_opts, messages: [{ role: 'user', content: 'hi' }])
      expect(m.message[:messages]).to eq([{ role: 'user', content: 'hi' }])
    end

    it 'includes model from options' do
      expect(msg.message[:model]).to eq('gpt-4o')
    end

    it 'includes reply_to from options' do
      expect(msg.message[:reply_to]).to eq('agent.queue')
    end

    it 'includes correlation_id from options' do
      expect(msg.message[:correlation_id]).to eq('abc-123')
    end

    it 'sets optional fields to nil when not provided' do
      expect(msg.message[:intent]).to be_nil
      expect(msg.message[:signed_token]).to be_nil
      expect(msg.message[:provider]).to be_nil
      expect(msg.message[:tier]).to be_nil
    end
  end
end

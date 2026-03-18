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

require 'legion/extensions/llm/gateway/transport/messages/metering_event'

RSpec.describe Legion::Extensions::LLM::Gateway::Transport::Messages::MeteringEvent do
  let(:valid_opts) do
    { request_type: 'completion', provider: 'openai' }
  end

  subject(:msg) { described_class.new(**valid_opts) }

  describe '#routing_key' do
    it 'includes request_type in the routing key' do
      expect(msg.routing_key).to eq('metering.completion')
    end

    it 'defaults to unknown when request_type is absent' do
      m = described_class.new(provider: 'openai')
      expect(m.routing_key).to eq('metering.unknown')
    end
  end

  describe '#type' do
    it 'returns metering_event' do
      expect(msg.type).to eq('metering_event')
    end
  end

  describe '#encrypt?' do
    it 'returns false' do
      expect(msg.encrypt?).to be(false)
    end
  end

  describe '#validate' do
    it 'raises when request_type is missing' do
      m = described_class.new(provider: 'openai')
      expect { m.validate }.to raise_error('request_type is required')
    end

    it 'raises when provider is missing' do
      m = described_class.new(request_type: 'completion')
      expect { m.validate }.to raise_error('provider is required')
    end

    it 'sets @valid to true when all required fields are present' do
      msg.validate
      expect(msg.instance_variable_get(:@valid)).to be(true)
    end
  end

  describe '#message' do
    it 'returns a hash with all expected keys' do
      result = msg.message
      expected_keys = %i[
        node_id worker_id agent_id request_type tier provider model_id
        input_tokens output_tokens thinking_tokens total_tokens
        latency_ms wall_clock_ms routing_reason recorded_at
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

    it 'defaults total_tokens to 0' do
      expect(msg.message[:total_tokens]).to eq(0)
    end

    it 'defaults latency_ms to 0' do
      expect(msg.message[:latency_ms]).to eq(0)
    end

    it 'defaults wall_clock_ms to 0' do
      expect(msg.message[:wall_clock_ms]).to eq(0)
    end

    it 'sets recorded_at when not provided' do
      expect(msg.message[:recorded_at]).not_to be_nil
    end

    it 'uses provided recorded_at value' do
      ts = '2026-01-01T00:00:00Z'
      m = described_class.new(**valid_opts, recorded_at: ts)
      expect(m.message[:recorded_at]).to eq(ts)
    end

    it 'includes request_type from options' do
      expect(msg.message[:request_type]).to eq('completion')
    end

    it 'includes provider from options' do
      expect(msg.message[:provider]).to eq('openai')
    end
  end
end

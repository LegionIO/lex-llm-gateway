# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/llm/gateway/runners/metering'

RSpec.describe Legion::Extensions::LLM::Gateway::Runners::Metering do
  describe '.build_event' do
    it 'returns a hash with all expected keys' do
      result = described_class.build_event(request_type: 'completion', provider: 'openai')
      expected_keys = %i[
        node_id worker_id agent_id request_type tier provider model_id
        input_tokens output_tokens thinking_tokens total_tokens
        latency_ms wall_clock_ms routing_reason recorded_at
      ]
      expect(result.keys).to match_array(expected_keys)
    end

    it 'calculates total_tokens as the sum of input, output, and thinking tokens' do
      result = described_class.build_event(input_tokens: 10, output_tokens: 20, thinking_tokens: 5)
      expect(result[:total_tokens]).to eq(35)
    end

    it 'defaults input_tokens to 0 when not provided' do
      expect(described_class.build_event[:input_tokens]).to eq(0)
    end

    it 'defaults output_tokens to 0 when not provided' do
      expect(described_class.build_event[:output_tokens]).to eq(0)
    end

    it 'defaults thinking_tokens to 0 when not provided' do
      expect(described_class.build_event[:thinking_tokens]).to eq(0)
    end

    it 'defaults total_tokens to 0 when no tokens provided' do
      expect(described_class.build_event[:total_tokens]).to eq(0)
    end

    it 'sets recorded_at to an ISO8601 UTC string' do
      result = described_class.build_event
      expect(result[:recorded_at]).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/)
    end

    it 'passes through provider' do
      expect(described_class.build_event(provider: 'anthropic')[:provider]).to eq('anthropic')
    end

    it 'passes through model_id' do
      expect(described_class.build_event(model_id: 'claude-3-5-sonnet')[:model_id]).to eq('claude-3-5-sonnet')
    end

    it 'passes through tier' do
      expect(described_class.build_event(tier: 'cloud')[:tier]).to eq('cloud')
    end

    it 'passes through routing_reason' do
      expect(described_class.build_event(routing_reason: 'cost')[:routing_reason]).to eq('cost')
    end

    it 'ignores unknown keyword arguments' do
      expect { described_class.build_event(unknown_key: 'value') }.not_to raise_error
    end
  end

  describe '.publish_or_spool' do
    let(:event) { { request_type: 'completion', provider: 'openai' } }

    context 'when transport is connected' do
      before do
        allow(described_class).to receive(:transport_connected?).and_return(true)
        allow(described_class).to receive(:publish_event)
      end

      it 'returns :published' do
        expect(described_class.publish_or_spool(event)).to eq(:published)
      end

      it 'calls publish_event with the event' do
        described_class.publish_or_spool(event)
        expect(described_class).to have_received(:publish_event).with(event)
      end
    end

    context 'when transport is down but spool is available' do
      before do
        allow(described_class).to receive(:transport_connected?).and_return(false)
        allow(described_class).to receive(:spool_available?).and_return(true)
        allow(described_class).to receive(:spool_event)
      end

      it 'returns :spooled' do
        expect(described_class.publish_or_spool(event)).to eq(:spooled)
      end

      it 'calls spool_event with the event' do
        described_class.publish_or_spool(event)
        expect(described_class).to have_received(:spool_event).with(event)
      end
    end

    context 'when neither transport nor spool is available' do
      before do
        allow(described_class).to receive(:transport_connected?).and_return(false)
        allow(described_class).to receive(:spool_available?).and_return(false)
      end

      it 'returns :dropped' do
        expect(described_class.publish_or_spool(event)).to eq(:dropped)
      end
    end
  end

  describe '.flush_spool' do
    context 'when spool is not available' do
      before { allow(described_class).to receive(:spool_available?).and_return(false) }

      it 'returns 0' do
        expect(described_class.flush_spool).to eq(0)
      end
    end

    context 'when transport is not connected' do
      before do
        allow(described_class).to receive(:spool_available?).and_return(true)
        allow(described_class).to receive(:transport_connected?).and_return(false)
      end

      it 'returns 0' do
        expect(described_class.flush_spool).to eq(0)
      end
    end

    context 'when both spool and transport are available' do
      let(:spool_double) { double('Spool') }
      let(:event1) { { request_type: 'completion', provider: 'openai' } }
      let(:event2) { { request_type: 'embedding', provider: 'openai' } }

      before do
        allow(described_class).to receive(:spool_available?).and_return(true)
        allow(described_class).to receive(:transport_connected?).and_return(true)
        stub_const('Legion::Data::Spool', double('SpoolClass'))
        allow(Legion::Data::Spool).to receive(:for).and_return(spool_double)
        allow(described_class).to receive(:publish_event)
        allow(spool_double).to receive(:flush).with(:metering).and_yield(event1).and_yield(event2).and_return(2)
      end

      it 'calls Spool.for with the gateway module' do
        described_class.flush_spool
        expect(Legion::Data::Spool).to have_received(:for).with(Legion::Extensions::LLM::Gateway)
      end

      it 'publishes each flushed event' do
        described_class.flush_spool
        expect(described_class).to have_received(:publish_event).with(event1)
        expect(described_class).to have_received(:publish_event).with(event2)
      end

      it 'returns the count from flush' do
        expect(described_class.flush_spool).to eq(2)
      end
    end
  end

  describe '.transport_connected?' do
    context 'when Legion::Transport is not defined' do
      it 'returns false' do
        hide_const('Legion::Transport')
        expect(described_class.transport_connected?).to be(false)
      end
    end

    context 'when Legion::Transport is defined but does not respond to connected?' do
      before { stub_const('Legion::Transport', double('Transport')) }

      it 'returns false' do
        allow(Legion::Transport).to receive(:respond_to?).with(:connected?).and_return(false)
        expect(described_class.transport_connected?).to be(false)
      end
    end

    context 'when Legion::Transport.connected? returns true' do
      before { stub_const('Legion::Transport', double('Transport', connected?: true)) }

      it 'returns true' do
        expect(described_class.transport_connected?).to be(true)
      end
    end

    context 'when Legion::Transport.connected? returns false' do
      before { stub_const('Legion::Transport', double('Transport', connected?: false)) }

      it 'returns false' do
        expect(described_class.transport_connected?).to be(false)
      end
    end
  end

  describe '.spool_available?' do
    context 'when Legion::Data::Spool is not defined' do
      it 'returns false' do
        hide_const('Legion::Data::Spool')
        expect(described_class.spool_available?).to be(false)
      end
    end

    context 'when Legion::Data::Spool is defined' do
      before { stub_const('Legion::Data::Spool', double('Spool')) }

      it 'returns true' do
        expect(described_class.spool_available?).to be_truthy
      end
    end
  end

  describe '.publish_event' do
    let(:event) { { request_type: 'completion', provider: 'openai', node_id: 'n1' } }
    let(:message_double) { double('MeteringEvent') }

    before do
      metering_event_class = double('MeteringEventClass')
      stub_const(
        'Legion::Extensions::LLM::Gateway::Transport::Messages::MeteringEvent',
        metering_event_class
      )
      allow(metering_event_class).to receive(:new).with(**event).and_return(message_double)
      allow(message_double).to receive(:publish)
    end

    it 'instantiates MeteringEvent with the event and calls publish' do
      described_class.publish_event(event)
      expect(message_double).to have_received(:publish)
    end
  end

  describe '.spool_event' do
    let(:event) { { request_type: 'completion', provider: 'openai' } }
    let(:spool_double) { double('Spool') }

    before do
      stub_const('Legion::Data::Spool', double('SpoolClass'))
      allow(Legion::Data::Spool).to receive(:for).and_return(spool_double)
      allow(spool_double).to receive(:write)
    end

    it 'writes the event to the metering spool' do
      described_class.spool_event(event)
      expect(spool_double).to have_received(:write).with(:metering, event)
    end
  end
end

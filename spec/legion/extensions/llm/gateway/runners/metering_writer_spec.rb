# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/llm/gateway/runners/metering_writer'

RSpec.describe Legion::Extensions::LLM::Gateway::Runners::MeteringWriter do
  describe '.write_metering_record' do
    let(:payload) do
      {
        worker_id: 'worker-abc',
        task_id: 42,
        provider: 'anthropic',
        model_id: 'claude-opus-4-6',
        input_tokens: 100,
        output_tokens: 50,
        thinking_tokens: 10,
        total_tokens: 160,
        latency_ms: 300,
        wall_clock_ms: 350,
        routing_reason: 'cost',
        recorded_at: nil
      }
    end

    context 'when data is not connected' do
      before { allow(described_class).to receive(:data_connected?).and_return(false) }

      it 'returns success: false with data_not_connected error' do
        result = described_class.write_metering_record(payload)
        expect(result).to eq({ success: false, error: 'data_not_connected' })
      end
    end

    context 'when data is connected' do
      let(:dataset_double) { double('dataset') }
      let(:connection_double) { double('connection') }

      before do
        allow(described_class).to receive(:data_connected?).and_return(true)
        stub_const('Legion::Data', double('Data', connection: connection_double))
        allow(connection_double).to receive(:[]).with(:metering_records).and_return(dataset_double)
        allow(dataset_double).to receive(:insert)
      end

      it 'returns success: true' do
        result = described_class.write_metering_record(payload)
        expect(result[:success]).to be(true)
      end

      it 'inserts the normalized record into metering_records' do
        described_class.write_metering_record(payload)
        expect(dataset_double).to have_received(:insert)
      end

      it 'includes the record in the response' do
        result = described_class.write_metering_record(payload)
        expect(result[:recorded]).to be_a(Hash)
        expect(result[:recorded][:worker_id]).to eq('worker-abc')
      end

      it 'normalizes input_tokens to integer' do
        payload[:input_tokens] = '75'
        result = described_class.write_metering_record(payload)
        expect(result[:recorded][:input_tokens]).to eq(75)
      end

      it 'normalizes output_tokens to integer' do
        payload[:output_tokens] = '30'
        result = described_class.write_metering_record(payload)
        expect(result[:recorded][:output_tokens]).to eq(30)
      end

      it 'normalizes thinking_tokens to integer' do
        payload[:thinking_tokens] = '5'
        result = described_class.write_metering_record(payload)
        expect(result[:recorded][:thinking_tokens]).to eq(5)
      end

      it 'normalizes total_tokens to integer' do
        payload[:total_tokens] = '110'
        result = described_class.write_metering_record(payload)
        expect(result[:recorded][:total_tokens]).to eq(110)
      end

      it 'defaults recorded_at to UTC now when not provided' do
        before_time = Time.now.utc
        result = described_class.write_metering_record(payload)
        after_time = Time.now.utc
        expect(result[:recorded][:recorded_at]).to be_between(before_time, after_time)
      end

      it 'uses provided recorded_at when given' do
        fixed_time = Time.utc(2026, 3, 18, 12, 0, 0)
        payload[:recorded_at] = fixed_time
        result = described_class.write_metering_record(payload)
        expect(result[:recorded][:recorded_at]).to eq(fixed_time)
      end
    end
  end

  describe '.data_connected?' do
    context 'when Legion::Data is not defined' do
      it 'returns false' do
        hide_const('Legion::Data')
        expect(described_class.data_connected?).to be(false)
      end
    end

    context 'when Legion::Data does not respond to connection' do
      before { stub_const('Legion::Data', double('Data')) }

      it 'returns false' do
        allow(Legion::Data).to receive(:respond_to?).with(:connection).and_return(false)
        expect(described_class.data_connected?).to be(false)
      end
    end

    context 'when Legion::Data.connection returns nil' do
      before { stub_const('Legion::Data', double('Data', connection: nil)) }

      it 'returns false' do
        expect(described_class.data_connected?).to be(false)
      end
    end

    context 'when Legion::Data.connection returns a connection object' do
      before { stub_const('Legion::Data', double('Data', connection: double('conn'))) }

      it 'returns true' do
        expect(described_class.data_connected?).to be(true)
      end
    end
  end

  describe '.normalize_record' do
    let(:payload) do
      {
        worker_id: 'w-1',
        task_id: 7,
        provider: 'openai',
        model_id: 'gpt-4o',
        input_tokens: 10,
        output_tokens: 20,
        thinking_tokens: 0,
        total_tokens: 30,
        latency_ms: 200,
        wall_clock_ms: 250,
        routing_reason: 'speed',
        recorded_at: nil
      }
    end

    it 'returns a hash with all expected keys' do
      result = described_class.normalize_record(payload)
      expected_keys = %i[
        worker_id task_id provider model_id
        input_tokens output_tokens thinking_tokens total_tokens
        latency_ms wall_clock_ms routing_reason recorded_at
      ]
      expect(result.keys).to match_array(expected_keys)
    end

    it 'coerces nil token fields to 0' do
      payload[:input_tokens] = nil
      result = described_class.normalize_record(payload)
      expect(result[:input_tokens]).to eq(0)
    end
  end
end

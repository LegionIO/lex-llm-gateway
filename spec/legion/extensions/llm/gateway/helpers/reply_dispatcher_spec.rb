# frozen_string_literal: true

require 'spec_helper'
require 'concurrent'
require 'legion/extensions/llm/gateway/helpers/rpc'
require 'legion/extensions/llm/gateway/helpers/reply_dispatcher'

RSpec.describe Legion::Extensions::Llm::Gateway::Helpers::ReplyDispatcher do
  before { described_class.reset! }

  after { described_class.reset! }

  describe '.register' do
    it 'returns a resolvable future' do
      future = described_class.register('cid-1')
      expect(future).to be_a(Concurrent::Promises::ResolvableFuture)
    end

    it 'increments pending count' do
      expect { described_class.register('cid-2') }
        .to change { described_class.pending_count }.by(1)
    end
  end

  describe '.deregister' do
    it 'removes the pending entry' do
      described_class.register('cid-3')
      expect { described_class.deregister('cid-3') }
        .to change { described_class.pending_count }.by(-1)
    end

    it 'does nothing for unknown correlation ids' do
      expect { described_class.deregister('unknown') }.not_to raise_error
    end
  end

  describe '.handle_delivery' do
    it 'resolves the matching future with the parsed payload' do
      future = described_class.register('cid-4')
      described_class.handle_delivery({ correlation_id: 'cid-4', response: 'hello' })
      result = future.value!(1)
      expect(result[:response]).to eq('hello')
      expect(result[:success]).to be(true)
    end

    it 'uses correlation_id from properties when available' do
      future = described_class.register('cid-5')
      described_class.handle_delivery({ response: 'data' }, { correlation_id: 'cid-5' })
      result = future.value!(1)
      expect(result[:success]).to be(true)
    end

    it 'ignores unknown correlation ids' do
      expect { described_class.handle_delivery({ correlation_id: 'no-match' }) }.not_to raise_error
    end

    it 'removes the entry from pending after resolving' do
      described_class.register('cid-6')
      described_class.handle_delivery({ correlation_id: 'cid-6' })
      expect(described_class.pending_count).to eq(0)
    end

    it 'parses JSON string payloads' do
      future = described_class.register('cid-7')
      described_class.handle_delivery('{"correlation_id":"cid-7","data":"test"}')
      result = future.value!(1)
      expect(result[:data]).to eq('test')
    end
  end

  describe '.reset!' do
    it 'clears all pending futures' do
      described_class.register('cid-8')
      described_class.register('cid-9')
      described_class.reset!
      expect(described_class.pending_count).to eq(0)
    end
  end

  describe 'concurrent access' do
    it 'handles multiple concurrent registrations and resolutions' do
      futures = {}
      10.times { |i| futures[i] = described_class.register("cid-concurrent-#{i}") }
      expect(described_class.pending_count).to eq(10)

      futures.each_key do |i|
        described_class.handle_delivery({ correlation_id: "cid-concurrent-#{i}", index: i })
      end

      futures.each do |i, future|
        result = future.value!(1)
        expect(result[:index]).to eq(i)
        expect(result[:success]).to be(true)
      end

      expect(described_class.pending_count).to eq(0)
    end
  end
end

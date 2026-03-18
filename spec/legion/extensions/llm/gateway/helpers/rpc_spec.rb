# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/llm/gateway/helpers/rpc'

RSpec.describe Legion::Extensions::LLM::Gateway::Helpers::Rpc do
  describe '.generate_correlation_id' do
    it 'returns a UUID-format string' do
      id = described_class.generate_correlation_id
      expect(id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end

    it 'returns unique values on each call' do
      ids = Array.new(5) { described_class.generate_correlation_id }
      expect(ids.uniq.length).to eq(5)
    end
  end

  describe '.agent_queue_name' do
    context 'when Legion::Transport is not defined' do
      it 'returns nil' do
        hide_const('Legion::Transport')
        expect(described_class.agent_queue_name).to be_nil
      end
    end

    context 'when Legion::Transport is defined and responds to agent_queue_name' do
      it 'returns the transport queue name' do
        transport = double('Legion::Transport')
        allow(transport).to receive(:respond_to?).with(:agent_queue_name).and_return(true)
        allow(transport).to receive(:agent_queue_name).and_return('agent.worker-abc123')
        stub_const('Legion::Transport', transport)
        expect(described_class.agent_queue_name).to eq('agent.worker-abc123')
      end
    end
  end

  describe '.build_reply_headers' do
    it 'returns a hash with :reply_to and :correlation_id keys' do
      headers = described_class.build_reply_headers(correlation_id: 'test-id')
      expect(headers).to have_key(:reply_to)
      expect(headers).to have_key(:correlation_id)
    end

    it 'includes the correlation_id passed in' do
      cid = 'abc-123-xyz'
      headers = described_class.build_reply_headers(correlation_id: cid)
      expect(headers[:correlation_id]).to eq(cid)
    end
  end
end

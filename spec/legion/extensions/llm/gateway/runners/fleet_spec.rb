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

require 'legion/extensions/llm/gateway/helpers/auth'
require 'legion/extensions/llm/gateway/helpers/rpc'
require 'legion/extensions/llm/gateway/transport/messages/inference_request'
require 'legion/extensions/llm/gateway/runners/fleet'

RSpec.describe Legion::Extensions::LLM::Gateway::Runners::Fleet do
  let(:auth_helper) { Legion::Extensions::LLM::Gateway::Helpers::Auth }
  let(:rpc_helper) { Legion::Extensions::LLM::Gateway::Helpers::Rpc }
  let(:inference_request_class) do
    Legion::Extensions::LLM::Gateway::Transport::Messages::InferenceRequest
  end

  let(:message_double) { double('InferenceRequest', publish: nil) }

  before do
    stub_const('Legion::Transport', double('Transport', connected?: true, agent_queue_name: 'agent.queue.test'))
    stub_const('Legion::Settings', double('Settings'))
    allow(Legion::Settings).to receive(:[]).with(:llm).and_return(
      routing: { use_fleet: true, fleet: { timeout_seconds: 60, require_auth: false } }
    )
    allow(auth_helper).to receive(:sign_request).and_return('fake.jwt.token')
    allow(rpc_helper).to receive(:generate_correlation_id).and_return('test-uuid')
    allow(rpc_helper).to receive(:agent_queue_name).and_return('agent.queue.test')
    allow(inference_request_class).to receive(:new).and_return(message_double)
  end

  describe '.dispatch' do
    context 'when fleet is not available' do
      it 'returns fleet_unavailable error hash' do
        allow(described_class).to receive(:fleet_available?).and_return(false)
        result = described_class.dispatch(model: 'gpt-4o', messages: [])
        expect(result).to eq({ success: false, error: 'fleet_unavailable' })
      end
    end

    context 'when JWT signing fails and require_auth? is true' do
      before do
        allow(auth_helper).to receive(:sign_request).and_return(nil)
        allow(Legion::Settings).to receive(:[]).with(:llm).and_return(
          routing: { use_fleet: true, fleet: { timeout_seconds: 60, require_auth: true } }
        )
      end

      it 'returns fleet_auth_failed error hash' do
        result = described_class.dispatch(model: 'gpt-4o', messages: [])
        expect(result).to eq({ success: false, error: 'fleet_auth_failed' })
      end
    end

    context 'when JWT signing fails but require_auth? is false' do
      before do
        allow(auth_helper).to receive(:sign_request).and_return(nil)
      end

      it 'does not return auth error' do
        result = described_class.dispatch(model: 'gpt-4o', messages: [])
        expect(result[:error]).not_to eq('fleet_auth_failed')
      end
    end

    context 'when fleet is available and auth passes' do
      it 'calls Helpers::Auth.sign_request with model and intent' do
        expect(auth_helper).to receive(:sign_request).with({ model: 'gpt-4o', intent: 'summarize' })
        described_class.dispatch(model: 'gpt-4o', messages: [], intent: 'summarize')
      end

      it 'calls Helpers::Rpc.generate_correlation_id' do
        expect(rpc_helper).to receive(:generate_correlation_id).and_return('test-uuid')
        described_class.dispatch(model: 'gpt-4o', messages: [])
      end

      it 'calls publish_request' do
        expect(described_class).to receive(:publish_request).and_call_original
        described_class.dispatch(model: 'gpt-4o', messages: [])
      end

      it 'calls wait_for_response with the correlation_id and timeout' do
        expect(described_class).to receive(:wait_for_response).with('test-uuid', timeout: 60)
        described_class.dispatch(model: 'gpt-4o', messages: [])
      end

      it 'passes the custom timeout to wait_for_response when provided' do
        expect(described_class).to receive(:wait_for_response).with('test-uuid', timeout: 15)
        described_class.dispatch(model: 'gpt-4o', messages: [], timeout: 15)
      end
    end
  end

  describe '.fleet_available?' do
    context 'when Legion::Transport is not defined' do
      it 'returns false' do
        hide_const('Legion::Transport')
        expect(described_class.fleet_available?).to be(false)
      end
    end

    context 'when Legion::Transport.connected? returns false' do
      it 'returns false' do
        stub_const('Legion::Transport', double('Transport', connected?: false))
        expect(described_class.fleet_available?).to be(false)
      end
    end

    context 'when transport is connected and fleet is enabled' do
      it 'returns true' do
        expect(described_class.fleet_available?).to be(true)
      end
    end

    context 'when fleet_enabled? returns false' do
      it 'returns false' do
        allow(described_class).to receive(:fleet_enabled?).and_return(false)
        expect(described_class.fleet_available?).to be(false)
      end
    end
  end

  describe '.fleet_enabled?' do
    context 'when Legion::Settings is not defined' do
      it 'returns true' do
        hide_const('Legion::Settings')
        expect(described_class.fleet_enabled?).to be(true)
      end
    end

    context 'when settings has no routing config' do
      it 'returns true' do
        allow(Legion::Settings).to receive(:[]).with(:llm).and_return({})
        expect(described_class.fleet_enabled?).to be(true)
      end
    end

    context 'when use_fleet is false' do
      it 'returns false' do
        allow(Legion::Settings).to receive(:[]).with(:llm).and_return(
          routing: { use_fleet: false }
        )
        expect(described_class.fleet_enabled?).to be(false)
      end
    end

    context 'when use_fleet is true' do
      it 'returns true' do
        allow(Legion::Settings).to receive(:[]).with(:llm).and_return(
          routing: { use_fleet: true }
        )
        expect(described_class.fleet_enabled?).to be(true)
      end
    end

    context 'when use_fleet is not set' do
      it 'defaults to true' do
        allow(Legion::Settings).to receive(:[]).with(:llm).and_return(
          routing: {}
        )
        expect(described_class.fleet_enabled?).to be(true)
      end
    end
  end

  describe '.require_auth?' do
    context 'when Legion::Settings is not defined' do
      it 'returns false' do
        hide_const('Legion::Settings')
        expect(described_class.require_auth?).to be(false)
      end
    end

    context 'when there is no fleet config' do
      it 'returns false' do
        allow(Legion::Settings).to receive(:[]).with(:llm).and_return({ routing: {} })
        expect(described_class.require_auth?).to be(false)
      end
    end

    context 'when require_auth is true' do
      it 'returns true' do
        allow(Legion::Settings).to receive(:[]).with(:llm).and_return(
          routing: { fleet: { require_auth: true } }
        )
        expect(described_class.require_auth?).to be(true)
      end
    end

    context 'when require_auth is false' do
      it 'returns false' do
        allow(Legion::Settings).to receive(:[]).with(:llm).and_return(
          routing: { fleet: { require_auth: false } }
        )
        expect(described_class.require_auth?).to be(false)
      end
    end

    context 'when require_auth is not set' do
      it 'defaults to false' do
        allow(Legion::Settings).to receive(:[]).with(:llm).and_return(
          routing: { fleet: {} }
        )
        expect(described_class.require_auth?).to be(false)
      end
    end
  end

  describe '.resolve_timeout' do
    context 'when override is provided' do
      it 'returns the override value' do
        expect(described_class.resolve_timeout(45)).to eq(45)
      end
    end

    context 'when Legion::Settings is not defined' do
      it 'returns DEFAULT_TIMEOUT' do
        hide_const('Legion::Settings')
        expect(described_class.resolve_timeout(nil)).to eq(described_class::DEFAULT_TIMEOUT)
      end
    end

    context 'when settings path has timeout_seconds' do
      it 'returns the configured value' do
        allow(Legion::Settings).to receive(:[]).with(:llm).and_return(
          routing: { fleet: { timeout_seconds: 90 } }
        )
        expect(described_class.resolve_timeout(nil)).to eq(90)
      end
    end

    context 'when settings path does not have timeout_seconds' do
      it 'returns DEFAULT_TIMEOUT' do
        allow(Legion::Settings).to receive(:[]).with(:llm).and_return(
          routing: { fleet: {} }
        )
        expect(described_class.resolve_timeout(nil)).to eq(described_class::DEFAULT_TIMEOUT)
      end
    end

    context 'when settings returns nil' do
      it 'returns DEFAULT_TIMEOUT' do
        allow(Legion::Settings).to receive(:[]).with(:llm).and_return(nil)
        expect(described_class.resolve_timeout(nil)).to eq(described_class::DEFAULT_TIMEOUT)
      end
    end
  end

  describe '.error_result' do
    it 'returns a hash with success: false' do
      result = described_class.error_result('some_error')
      expect(result[:success]).to be(false)
    end

    it 'returns a hash with the provided error message' do
      result = described_class.error_result('some_error')
      expect(result[:error]).to eq('some_error')
    end
  end

  describe '.wait_for_response' do
    it 'returns a hash with success: false, fleet_timeout error, and correlation_id' do
      result = described_class.wait_for_response('test-uuid', timeout: 30)
      expect(result).to include(
        success: false,
        error: 'fleet_timeout',
        correlation_id: 'test-uuid'
      )
    end
  end
end

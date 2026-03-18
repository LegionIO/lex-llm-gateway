# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/llm/gateway/helpers/auth'

RSpec.describe Legion::Extensions::LLM::Gateway::Helpers::Auth do
  describe '.sign_request' do
    context 'when Legion::Crypt::JWT is not defined' do
      it 'returns nil' do
        hide_const('Legion::Crypt::JWT')
        expect(described_class.sign_request({ sub: 'worker-123' })).to be_nil
      end
    end

    context 'when Legion::Crypt::JWT is defined' do
      it 'calls Legion::Crypt::JWT.encode and returns the token' do
        jwt_double = double('Legion::Crypt::JWT')
        allow(jwt_double).to receive(:encode).with(payload: { sub: 'worker-123' }, ttl: 60).and_return('fake.jwt.token')
        stub_const('Legion::Crypt::JWT', jwt_double)
        expect(described_class.sign_request({ sub: 'worker-123' })).to eq('fake.jwt.token')
      end

      it 'returns nil when encode raises' do
        jwt_double = double('Legion::Crypt::JWT')
        allow(jwt_double).to receive(:encode).and_raise(StandardError, 'encode failed')
        stub_const('Legion::Crypt::JWT', jwt_double)
        expect(described_class.sign_request({ sub: 'worker-123' })).to be_nil
      end
    end
  end

  describe '.validate_token' do
    context 'when Legion::Crypt::JWT is not defined' do
      it 'returns nil' do
        hide_const('Legion::Crypt::JWT')
        expect(described_class.validate_token('some.jwt.token')).to be_nil
      end
    end

    context 'when Legion::Crypt::JWT is defined' do
      it 'calls Legion::Crypt::JWT.decode and returns the decoded payload' do
        jwt_double = double('Legion::Crypt::JWT')
        allow(jwt_double).to receive(:decode).with(token: 'some.jwt.token').and_return({ sub: 'worker-123' })
        stub_const('Legion::Crypt::JWT', jwt_double)
        expect(described_class.validate_token('some.jwt.token')).to eq({ sub: 'worker-123' })
      end

      it 'returns nil when decode raises' do
        jwt_double = double('Legion::Crypt::JWT')
        allow(jwt_double).to receive(:decode).and_raise(StandardError, 'decode failed')
        stub_const('Legion::Crypt::JWT', jwt_double)
        expect(described_class.validate_token('some.jwt.token')).to be_nil
      end
    end
  end
end

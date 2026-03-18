# frozen_string_literal: true

require 'spec_helper'

unless defined?(Legion::Extensions::Actors::Subscription)
  module Legion
    module Extensions
      module Actors
        class Subscription; end # rubocop:disable Lint/EmptyClass
      end
    end
  end
end

$LOADED_FEATURES << 'legion/extensions/actors/subscription'

require 'legion/extensions/llm/gateway/actors/metering_writer'

RSpec.describe Legion::Extensions::LLM::Gateway::Actor::MeteringWriter do
  subject(:actor) { described_class.allocate }

  describe '#runner_class' do
    it 'returns the metering writer runner class string' do
      expect(actor.runner_class).to eq('Legion::Extensions::LLM::Gateway::Runners::MeteringWriter')
    end
  end

  describe '#runner_function' do
    it 'returns write_metering_record' do
      expect(actor.runner_function).to eq('write_metering_record')
    end
  end
end

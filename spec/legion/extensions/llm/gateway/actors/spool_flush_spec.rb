# frozen_string_literal: true

require 'spec_helper'

unless defined?(Legion::Extensions::Actors::Every)
  module Legion
    module Extensions
      module Actors
        class Every; end # rubocop:disable Lint/EmptyClass
      end
    end
  end
end

$LOADED_FEATURES << 'legion/extensions/actors/every'

require 'legion/extensions/llm/gateway/actors/spool_flush'

RSpec.describe Legion::Extensions::LLM::Gateway::Actor::SpoolFlush do
  subject(:actor) { described_class.allocate }

  describe '#runner_class' do
    it 'returns the metering runner class string' do
      expect(actor.runner_class).to eq('Legion::Extensions::LLM::Gateway::Runners::Metering')
    end
  end

  describe '#runner_function' do
    it 'returns flush_spool' do
      expect(actor.runner_function).to eq('flush_spool')
    end
  end

  describe '#time' do
    it 'returns 60 seconds' do
      expect(actor.time).to eq(60)
    end
  end

  describe '#run_now?' do
    it 'returns false' do
      expect(actor.run_now?).to be(false)
    end
  end

  describe '#use_runner?' do
    it 'returns false' do
      expect(actor.use_runner?).to be(false)
    end
  end

  describe '#check_subtask?' do
    it 'returns false' do
      expect(actor.check_subtask?).to be(false)
    end
  end

  describe '#generate_task?' do
    it 'returns false' do
      expect(actor.generate_task?).to be(false)
    end
  end
end

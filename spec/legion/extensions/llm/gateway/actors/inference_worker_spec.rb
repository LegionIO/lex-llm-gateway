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

require 'legion/extensions/llm/gateway/actors/inference_worker'

RSpec.describe Legion::Extensions::LLM::Gateway::Actor::InferenceWorker do
  subject(:actor) { described_class.allocate }

  describe '#runner_class' do
    it 'returns the inference runner class string' do
      expect(actor.runner_class).to eq('Legion::Extensions::LLM::Gateway::Runners::Inference')
    end
  end

  describe '#runner_function' do
    it 'returns handle_fleet_request' do
      expect(actor.runner_function).to eq('handle_fleet_request')
    end
  end
end

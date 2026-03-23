# frozen_string_literal: true

require 'spec_helper'
require 'sequel'
require 'legion/extensions/llm/gateway/runners/usage_reporter'
require 'legion/extensions/llm/gateway/runners/metering_writer'
require 'legion/extensions/llm/gateway/helpers/usage_queries'

RSpec.describe Legion::Extensions::LLM::Gateway::Runners::UsageReporter do
  let(:queries) { Legion::Extensions::LLM::Gateway::Helpers::UsageQueries }
  let(:now) { Time.now.utc }

  before(:all) do
    @test_db = Sequel.sqlite
    @test_db.create_table(:metering_records) do
      primary_key :id
      String   :worker_id
      String   :task_id
      String   :provider
      String   :model_id
      Integer  :input_tokens, default: 0
      Integer  :output_tokens, default: 0
      Integer  :thinking_tokens, default: 0
      Integer  :total_tokens, default: 0
      Integer  :latency_ms, default: 0
      Integer  :wall_clock_ms, default: 0
      Float    :cost_usd, default: 0.0
      String   :routing_reason
      String   :status
      String   :event_type
      String   :extension
      String   :runner_function
      Time     :recorded_at
    end
  end

  before do
    @test_db[:metering_records].delete
    allow(described_class).to receive(:data_connected?).and_return(true)
    allow(queries).to receive(:metering_records).and_return(@test_db[:metering_records])
  end

  def insert_record(overrides = {})
    defaults = {
      worker_id: 'w-1', provider: 'anthropic', model_id: 'claude-sonnet-4-6',
      input_tokens: 1000, output_tokens: 500, cost_usd: 0.0105,
      recorded_at: now - 3600
    }
    @test_db[:metering_records].insert(defaults.merge(overrides))
  end

  describe '.summary' do
    it 'returns aggregate usage for the period' do
      insert_record(provider: 'anthropic', model_id: 'claude-sonnet-4-6', cost_usd: 0.01)
      insert_record(provider: 'openai', model_id: 'gpt-4o', cost_usd: 0.02)

      result = described_class.summary(since: now - 86_400, period: :day)
      expect(result[:total_requests]).to eq(2)
      expect(result[:total_cost_usd]).to eq(0.03)
      expect(result[:by_provider].size).to eq(2)
      expect(result[:by_model].size).to eq(2)
    end

    it 'returns zeros when no records exist' do
      result = described_class.summary(since: now - 86_400)
      expect(result[:total_requests]).to eq(0)
      expect(result[:total_cost_usd]).to eq(0.0)
    end

    it 'returns unavailable when data not connected' do
      allow(described_class).to receive(:data_connected?).and_return(false)
      result = described_class.summary
      expect(result[:error]).to eq('data_not_connected')
    end
  end

  describe '.worker_usage' do
    it 'returns usage for a specific worker' do
      insert_record(worker_id: 'w-1', cost_usd: 0.01)
      insert_record(worker_id: 'w-2', cost_usd: 0.02)
      insert_record(worker_id: 'w-1', cost_usd: 0.03)

      result = described_class.worker_usage(worker_id: 'w-1', since: now - 86_400)
      expect(result[:worker_id]).to eq('w-1')
      expect(result[:total_requests]).to eq(2)
      expect(result[:total_cost_usd]).to eq(0.04)
    end

    it 'returns zeros for unknown worker' do
      result = described_class.worker_usage(worker_id: 'nonexistent', since: now - 86_400)
      expect(result[:total_requests]).to eq(0)
    end
  end

  describe '.budget_check' do
    it 'returns ok when under budget' do
      insert_record(cost_usd: 10.0)

      result = described_class.budget_check(budget_usd: 100.0, period: :month)
      expect(result[:status]).to eq(:ok)
      expect(result[:budget]).to eq(100.0)
      expect(result[:spent]).to eq(10.0)
      expect(result[:remaining]).to eq(90.0)
    end

    it 'returns warning when approaching budget' do
      insert_record(cost_usd: 85.0)

      result = described_class.budget_check(budget_usd: 100.0, threshold: 0.8, period: :month)
      expect(result[:status]).to eq(:warning)
    end

    it 'returns exceeded when over budget' do
      insert_record(cost_usd: 110.0)

      result = described_class.budget_check(budget_usd: 100.0, period: :month)
      expect(result[:status]).to eq(:exceeded)
      expect(result[:remaining]).to eq(0.0)
    end

    it 'uses configured defaults when no args provided' do
      allow(described_class).to receive(:configured_budget).and_return(50.0)
      allow(described_class).to receive(:configured_threshold).and_return(0.9)
      insert_record(cost_usd: 5.0)

      result = described_class.budget_check(period: :month)
      expect(result[:budget]).to eq(50.0)
      expect(result[:status]).to eq(:ok)
    end
  end

  describe '.top_consumers' do
    it 'returns top workers by cost' do
      3.times { insert_record(worker_id: 'w-heavy', cost_usd: 10.0) }
      insert_record(worker_id: 'w-light', cost_usd: 0.01)

      results = described_class.top_consumers(since: now - 86_400, limit: 5)
      expect(results.first[:worker_id]).to eq('w-heavy')
      expect(results.first[:total_cost]).to eq(30.0)
      expect(results.size).to eq(2)
    end

    it 'groups by model when specified' do
      insert_record(model_id: 'claude-sonnet-4-6', cost_usd: 5.0)
      insert_record(model_id: 'gpt-4o', cost_usd: 10.0)

      results = described_class.top_consumers(since: now - 86_400, group_by: :model_id)
      expect(results.first[:model_id]).to eq('gpt-4o')
    end

    it 'respects limit' do
      5.times { |i| insert_record(worker_id: "w-#{i}", cost_usd: i.to_f) }

      results = described_class.top_consumers(since: now - 86_400, limit: 3)
      expect(results.size).to eq(3)
    end
  end

  describe 'UsageQueries.period_start' do
    it 'calculates hour start' do
      result = queries.period_start(:hour)
      expect(result).to be_within(5).of(Time.now.utc - 3600)
    end

    it 'calculates day start' do
      result = queries.period_start(:day)
      expect(result.hour).to eq(0)
      expect(result.min).to eq(0)
    end

    it 'calculates month start' do
      result = queries.period_start(:month)
      expect(result.day).to eq(1)
      expect(result.hour).to eq(0)
    end
  end
end

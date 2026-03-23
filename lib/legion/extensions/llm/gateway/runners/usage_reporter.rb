# frozen_string_literal: true

require_relative '../helpers/usage_queries'

module Legion
  module Extensions
    module LLM
      module Gateway
        module Runners
          module UsageReporter
            DEFAULT_BUDGET_USD = 100.0
            DEFAULT_ALERT_THRESHOLD = 0.8

            module_function

            def summary(since: nil, period: :day)
              return unavailable_result unless data_connected?

              since ||= queries.period_start(period)
              dataset = queries.metering_since(since)
              build_summary(dataset, period, since)
            end

            def worker_usage(worker_id:, since: nil, period: :day)
              return unavailable_result unless data_connected?

              since ||= queries.period_start(period)
              dataset = queries.metering_since(since).where(worker_id: worker_id)
              build_worker_summary(dataset, worker_id, period, since)
            end

            def budget_check(budget_usd: nil, threshold: nil, period: :month)
              return unavailable_result unless data_connected?

              budget = budget_usd || configured_budget
              alert_at = threshold || configured_threshold
              spent = queries.metering_since(queries.period_start(period)).sum(:cost_usd).to_f
              build_budget_result(budget, spent, alert_at, period)
            end

            def top_consumers(since: nil, period: :day, limit: 10, group_by: :worker_id)
              return unavailable_result unless data_connected?

              since ||= queries.period_start(period)
              queries.aggregate_by_column(queries.metering_since(since), group_by.to_sym, limit)
            end

            def queries
              Helpers::UsageQueries
            end

            def data_connected?
              MeteringWriter.data_connected?
            end

            def build_summary(dataset, period, since)
              queries.aggregate_totals(dataset).merge(
                period: period.to_s,
                since: since.iso8601,
                by_provider: queries.grouped_rows(dataset, :provider),
                by_model: queries.grouped_rows(dataset, :model_id)
              )
            end

            def build_worker_summary(dataset, worker_id, period, since)
              queries.aggregate_totals(dataset).merge(
                worker_id: worker_id,
                period: period.to_s,
                since: since.iso8601,
                by_model: queries.grouped_rows(dataset, :model_id)
              )
            end

            def build_budget_result(budget, spent, alert_at, period)
              ratio = budget.positive? ? (spent / budget) : 0.0
              {
                period: period.to_s,
                budget: budget.round(2),
                spent: spent.round(4),
                remaining: [(budget - spent), 0.0].max.round(4),
                ratio: ratio.round(4),
                status: budget_status(ratio, alert_at)
              }
            end

            def budget_status(ratio, alert_at)
              return :exceeded if ratio >= 1.0
              return :warning if ratio >= alert_at

              :ok
            end

            def configured_budget
              llm_setting(:budget, :monthly_usd)&.to_f || DEFAULT_BUDGET_USD
            end

            def configured_threshold
              llm_setting(:budget, :alert_threshold)&.to_f || DEFAULT_ALERT_THRESHOLD
            end

            def llm_setting(*keys)
              return nil unless defined?(Legion::Settings)

              settings = Legion::Settings[:llm] rescue nil # rubocop:disable Style/RescueModifier
              return nil unless settings.is_a?(Hash)

              settings.dig(*keys)
            end

            def unavailable_result
              { success: false, error: 'data_not_connected' }
            end
          end
        end
      end
    end
  end
end

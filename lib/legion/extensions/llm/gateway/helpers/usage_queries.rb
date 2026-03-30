# frozen_string_literal: true

module Legion
  module Extensions
    module LLM
      module Gateway
        module Helpers
          module UsageQueries
            module_function

            def metering_records
              Legion::Data.connection[:metering_records]
            end

            def metering_since(since)
              metering_records.where { recorded_at >= since }
            end

            def aggregate_totals(dataset)
              {
                total_requests: dataset.count,
                total_cost_usd: dataset.sum(:cost_usd).to_f.round(4),
                total_input:    dataset.sum(:input_tokens).to_i,
                total_output:   dataset.sum(:output_tokens).to_i
              }
            end

            def grouped_rows(dataset, column)
              grouped_query(dataset, column).limit(20).all.map do |row|
                format_grouped_row(row, column, name_key: true)
              end
            end

            def aggregate_by_column(dataset, column, limit)
              grouped_query(dataset, column).limit(limit).all.map do |row|
                format_grouped_row(row, column)
              end
            end

            def grouped_query(dataset, column)
              base = dataset.exclude(column => nil).group_and_count(column)
              append_aggregates(base).order(::Sequel.desc(:total_cost))
            end

            def append_aggregates(query)
              query.select_append { sum(cost_usd).as(total_cost) }
                   .select_append { sum(input_tokens).as(total_input) }
                   .select_append { sum(output_tokens).as(total_output) }
            end

            def format_grouped_row(row, column, name_key: false)
              key = name_key ? :name : column
              {
                key => row[column],
                total_cost: row[:total_cost].to_f.round(4),
                total_input: row[:total_input].to_i,
                total_output: row[:total_output].to_i,
                requests: row[:count].to_i
              }
            end

            def period_start(period)
              now = Time.now.utc
              case period.to_sym
              when :hour  then now - 3600
              when :week  then day_start(now) - ((now.wday % 7) * 86_400)
              when :month then Time.utc(now.year, now.month, 1)
              else day_start(now)
              end
            end

            def day_start(time)
              Time.utc(time.year, time.month, time.day)
            end
          end
        end
      end
    end
  end
end

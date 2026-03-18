# frozen_string_literal: true

module Legion
  module Extensions
    module LLM
      module Gateway
        module Runners
          module Inference
            module_function

            def chat(model: nil, provider: nil, **opts)
              start_ms = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
              response = dispatch_chat(model: model, provider: provider, **opts)
              elapsed_ms = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond) - start_ms
              meter_response(response, request_type: 'chat', provider: provider,
                                       model_id: model, latency_ms: elapsed_ms, **opts.slice(:tier, :intent))
              response
            end

            def embed(text: nil, model: nil, provider: nil, **)
              start_ms = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
              response = call_llm(:embed, text: text, model: model, provider: provider, **)
              elapsed_ms = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond) - start_ms
              meter_response(response, request_type: 'embed', provider: provider, model_id: model,
                                       latency_ms: elapsed_ms)
              response
            end

            def structured(messages: nil, schema: nil, model: nil, provider: nil, **)
              start_ms = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
              response = call_llm(:structured, messages: messages, schema: schema, model: model,
                                               provider: provider, **)
              elapsed_ms = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond) - start_ms
              meter_response(response, request_type: 'structured', provider: provider, model_id: model,
                                       latency_ms: elapsed_ms)
              response
            end

            def dispatch_chat(message: nil, model: nil, provider: nil, **opts)
              tier = opts[:tier]
              intent = opts[:intent]
              if tier == 'fleet' && fleet_available?
                Fleet.dispatch(model: model, messages: [{ role: 'user', content: message }],
                               intent: intent)
              else
                call_llm(:chat, message: message, model: model, provider: provider, **opts)
              end
            end

            def fleet_available?
              defined?(Legion::Extensions::LLM::Gateway::Runners::Fleet) &&
                Fleet.respond_to?(:fleet_available?) && Fleet.fleet_available?
            end

            def call_llm(method_name, **)
              return { error: 'llm_not_available' } unless defined?(Legion::LLM)

              direct = :"#{method_name}_direct"
              if Legion::LLM.respond_to?(direct)
                Legion::LLM.public_send(direct, **)
              else
                Legion::LLM.public_send(method_name, **)
              end
            end

            def meter_response(response, **)
              Metering.publish_or_spool(build_meter_event(response, **))
            end

            def build_meter_event(response, **opts)
              Metering.build_event(**base_meter_fields(response, opts), **token_fields(response))
            end

            def base_meter_fields(response, opts)
              {
                request_type: opts[:request_type],
                provider: extract_provider(response, opts[:provider]),
                model_id: extract_model(response, opts[:model_id]),
                latency_ms: opts[:latency_ms],
                tier: opts[:tier],
                routing_reason: opts[:intent]
              }
            end

            def token_fields(response)
              {
                input_tokens: extract_tokens(response, :input_tokens),
                output_tokens: extract_tokens(response, :output_tokens),
                thinking_tokens: extract_tokens(response, :thinking_tokens)
              }
            end

            def extract_tokens(response, field)
              return 0 unless response.respond_to?(field)

              response.public_send(field).to_i
            end

            def extract_provider(response, fallback)
              return response.provider if response.respond_to?(:provider)

              fallback
            end

            def extract_model(response, fallback)
              return response.model if response.respond_to?(:model)

              fallback
            end
          end
        end
      end
    end
  end
end

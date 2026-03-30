# frozen_string_literal: true

module Legion
  module Extensions
    module LLM
      module Gateway
        module Runners
          module Inference
            module_function

            def chat(model: nil, provider: nil, **opts)
              if pipeline_available?
                log_deprecation(:chat)
                return Legion::LLM.chat(model: model, provider: provider, # rubocop:disable Legion/HelperMigration/DirectLlm
                                        caller: { extension: 'lex-llm-gateway', operation: 'inference' }, **opts)
              end

              start_ms = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC, :millisecond)
              response = dispatch_chat(model: model, provider: provider, **opts)
              elapsed_ms = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC, :millisecond) - start_ms
              meter_response(response, request_type: 'chat', provider: provider,
                                       model_id: model, latency_ms: elapsed_ms, **opts.slice(:tier, :intent))
              response
            end

            def embed(text: nil, model: nil, provider: nil, **)
              if pipeline_available?
                log_deprecation(:embed)
                return Legion::LLM.embed(text, model: model, provider: provider, # rubocop:disable Legion/HelperMigration/DirectLlm
                                         caller: { extension: 'lex-llm-gateway', operation: 'inference' }, **)
              end

              start_ms = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC, :millisecond)
              response = dispatch_embed(text: text, model: model, provider: provider, **)
              elapsed_ms = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC, :millisecond) - start_ms
              meter_response(response, request_type: 'embed', provider: provider, model_id: model,
                                       latency_ms: elapsed_ms)
              response
            end

            def structured(messages: nil, schema: nil, model: nil, provider: nil, **)
              if pipeline_available?
                log_deprecation(:structured)
                return Legion::LLM.structured(messages: messages, schema: schema, model: model, # rubocop:disable Legion/HelperMigration/DirectLlm
                                              provider: provider,
                                              caller: { extension: 'lex-llm-gateway', operation: 'inference' }, **)
              end

              start_ms = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC, :millisecond)
              response = dispatch_structured(messages: messages, schema: schema, model: model,
                                             provider: provider, **)
              elapsed_ms = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC, :millisecond) - start_ms
              meter_response(response, request_type: 'structured', provider: provider, model_id: model,
                                       latency_ms: elapsed_ms)
              response
            end

            def pipeline_available?
              defined?(Legion::LLM::Pipeline::Executor) &&
                defined?(Legion::LLM) &&
                Legion::LLM.respond_to?(:pipeline_enabled?) &&
                Legion::LLM.pipeline_enabled?
            end

            def log_deprecation(method)
              return unless defined?(Legion::Logging) # rubocop:disable Legion/HelperMigration/LoggingGuard

              Legion::Logging.warn("lex-llm-gateway is deprecated for #{method}, use Legion::LLM.#{method} directly") # rubocop:disable Legion/HelperMigration/DirectLogging
            end

            def dispatch_chat(message: nil, messages: nil, model: nil, provider: nil, **opts)
              tier = opts[:tier]
              Legion::Logging.debug("[Gateway::Inference] dispatch_chat tier=#{tier}") if defined?(Legion::Logging) # rubocop:disable Legion/HelperMigration/DirectLogging, Legion/HelperMigration/LoggingGuard
              if tier == 'fleet' && fleet_available?
                fleet_messages = messages || [{ role: 'user', content: message }]
                Fleet.dispatch(model: model, messages: fleet_messages, intent: opts[:intent])
              else
                call_llm(:chat, message: message, messages: messages, model: model,
                                provider: provider, **opts)
              end
            end

            def dispatch_embed(text: nil, model: nil, provider: nil, **opts)
              if opts[:tier] == 'fleet' && fleet_available?
                Fleet.dispatch(model: model, messages: [{ role: 'user', content: text }],
                               intent: opts[:intent], request_type: 'embed', text: text)
              else
                call_llm(:embed, text: text, model: model, provider: provider, **opts)
              end
            end

            def dispatch_structured(messages: nil, schema: nil, model: nil, provider: nil, **opts)
              if opts[:tier] == 'fleet' && fleet_available?
                Fleet.dispatch(model: model, messages: messages, intent: opts[:intent],
                               request_type: 'structured', schema: schema)
              else
                call_llm(:structured, messages: messages, schema: schema, model: model,
                                      provider: provider, **opts)
              end
            end

            def fleet_available?
              defined?(Legion::Extensions::LLM::Gateway::Runners::Fleet) &&
                Fleet.respond_to?(:fleet_available?) && Fleet.fleet_available?
            end

            def call_llm(method_name, **)
              unless defined?(Legion::LLM)
                Legion::Logging.warn('[Gateway::Inference] Legion::LLM not defined') if defined?(Legion::Logging) # rubocop:disable Legion/HelperMigration/DirectLogging, Legion/HelperMigration/LoggingGuard
                return { error: 'llm_not_available' }
              end

              direct = :"#{method_name}_direct"
              target = Legion::LLM.respond_to?(direct) ? direct : method_name
              Legion::LLM.public_send(target, **)
            end

            def meter_response(response, **)
              Metering.publish_or_spool(build_meter_event(response, **))
            end

            def build_meter_event(response, **opts)
              Metering.build_event(**base_meter_fields(response, opts), **token_fields(response))
            end

            def base_meter_fields(response, opts)
              {
                request_type:   opts[:request_type],
                provider:       extract_provider(response, opts[:provider]),
                model_id:       extract_model(response, opts[:model_id]),
                latency_ms:     opts[:latency_ms],
                tier:           opts[:tier],
                routing_reason: opts[:intent]
              }
            end

            def token_fields(response)
              {
                input_tokens:    extract_tokens(response, :input_tokens),
                output_tokens:   extract_tokens(response, :output_tokens),
                thinking_tokens: extract_tokens(response, :thinking_tokens)
              }
            end

            def extract_tokens(response, field)
              response.respond_to?(field) ? response.public_send(field).to_i : 0
            end

            def extract_provider(response, fallback)
              response.respond_to?(:provider) ? response.provider : fallback
            end

            def extract_model(response, fallback)
              response.respond_to?(:model) ? response.model : fallback
            end
          end
        end
      end
    end
  end
end

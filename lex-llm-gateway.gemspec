# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'legion/extensions/llm/gateway/version'

Gem::Specification.new do |spec|
  spec.name          = 'lex-llm-gateway'
  spec.version       = Legion::Extensions::LLM::Gateway::VERSION
  spec.authors       = ['Esity']
  spec.email         = ['matthewdiverson@gmail.com']

  spec.summary       = 'Legion::Extensions::LLM::Gateway'
  spec.description   = 'LLM inference gateway: metering over RabbitMQ, fleet RPC dispatch, local disk spool'
  spec.homepage      = 'https://github.com/LegionIO/lex-llm-gateway'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.4'

  spec.metadata['homepage_uri']          = spec.homepage
  spec.metadata['source_code_uri']       = 'https://github.com/LegionIO/lex-llm-gateway'
  spec.metadata['changelog_uri']         = 'https://github.com/LegionIO/lex-llm-gateway/blob/main/CHANGELOG.md'
  spec.metadata['documentation_uri']     = 'https://github.com/LegionIO/lex-llm-gateway'
  spec.metadata['bug_tracker_uri']       = 'https://github.com/LegionIO/lex-llm-gateway/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir.glob('{lib,exe}/**/*') + %w[lex-llm-gateway.gemspec Gemfile README.md CHANGELOG.md LICENSE]
  end
  spec.require_paths = ['lib']

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rubocop-rspec'
end

# frozen_string_literal: true

if ENV['COVERAGE'] == 'true'
  require 'simplecov'

  SimpleCov.start do
    project_root = File.expand_path('..', __dir__)

    command_name 'spec:unit'

    add_filter do |source_file|
      !source_file.filename.start_with?(project_root)
    end
    add_filter 'config'
    add_filter '.rubies'
    add_filter 'spec'
    add_filter 'vendor'
    add_filter 'test_app'
    add_filter 'lib/mutant.rb' # simplecov bug not seeing default block is executed

    minimum_coverage 100
  end
end

# Require pathname first since warning support uses it
require 'pathname'

# Require warning support first in order to catch any warnings emitted during boot
require_relative './support/warning'
$stderr = MutantSpec::Warning::EXTRACTOR

require 'tempfile'
require 'concord'
require 'anima'
require 'adamantium'
require 'rspec/its'
require 'unparser/cli'
require 'mutant'
require 'mutant/meta'
require_relative 'support/test_app'

$LOAD_PATH << File.join(TestApp.root, 'lib')

require 'test_app'

Dir[File.expand_path('{support,shared}/**/*.rb', __dir__)].sort.each do |file|
  next if file.end_with?('/support/test_app.rb')

  require file
end

module Fixtures
  TEST_CONFIG = Mutant::Config::DEFAULT.with(reporter: Mutant::Reporter::Null.new)
  TEST_ENV    = Mutant::Env::Bootstrap.(TEST_CONFIG)
end # Fixtures

module ParserHelper
  def generate(node)
    Unparser.unparse(node)
  end

  def parse(string)
    Unparser.parse(string)
  end

  def parse_expression(string)
    Mutant::Config::DEFAULT.expression_parser.(string)
  end
end # ParserHelper

module XSpecHelper
  def verify_events
    expectations = raw_expectations
      .map { |expectation| XSpec::MessageExpectation.parse(**expectation) }

    XSpec::ExpectationVerifier.verify(self, expectations) do
      yield
    end
  end
end # XSpecHelper

RSpec.configure do |config|
  config.threadsafe = true
  config.extend(SharedContext)
  config.include(ParserHelper)
  config.include(Mutant::AST::Sexp)
  config.include(XSpecHelper)

  config.after(:suite) do
    $stderr = STDERR
    MutantSpec::Warning.assert_no_warnings
  end
end

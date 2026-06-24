# frozen_string_literal: true

require 'bundler/gem_helper'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require_relative 'lib/mutant/since_revision_resolver'

Bundler::GemHelper.install_tasks name: 'mutant'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new(:rubocop)

Rake.application.load_imports

task default: :spec

def mutant_since_revision
  Mutant::SinceRevisionResolver.new(Open3, Kernel).call(ENV['MUTANT_SINCE'])
end

task('metrics:mutant').clear
namespace :metrics do
  # TODO(#2): Remove scope-detection ignores once mutation coverage is established
  MUTANT_IGNORE_SUBJECTS = %w[
    source:lib/mutant/mutator/node/scope_detection.rb
    Mutant::AST::Regexp*
    Mutant::Expression::Namespace#prefix_match_length
    Mutant::Mutator::Node::Literal::Regex*
    Mutant::Zombifier*
    Mutant::Env#kill
    Mutant::Env#run_mutation_tests
    Mutant::Env#selections
    Mutant::Env#with_environment_variables
    Mutant::Config::Loader#document_root
    Mutant::CLIArgumentSanitizer#initialize
    Mutant::Integration::RspecSupport::SourceIndex#parse
    Mutant::CLI#config
    Mutant::CLI#dispatch
    Mutant::CLI#normalize_arguments
    Mutant::CLI#option_parser
    Mutant::CLI#parse
    Mutant::CLI#puts
    Mutant::CLI#warn_deprecation
    Mutant::CLI::Subcommands#handle_run
    Mutant::CLI::Subcommands#handle_environment
    Mutant::CLI::Subcommands#print_environment
    Mutant::CLI::Subcommands#print_run_help
    Mutant::CLI::Subcommands#print_run_help_and_exit
    Mutant::CLI::Subcommands#print_version_and_exit
    Mutant::CLI::Session#load_session_data
    Mutant::CLI::Session#print_session_show
    Mutant::CLI::Session#resolve_session_path
    Mutant::CLI::Options#add_filter_options
    Mutant::CLI::Options#add_mutation_options
    Mutant::CLI::Options#enable_fail_fast
    Mutant::CLI::Options#setup_integration
  ].freeze

  task :rubocop do
    Kernel.system('bundle', 'exec', 'rubocop') or fail 'Rubocop task is not successful'
  end

  task :reek do
    Kernel.system('bundle', 'exec', 'reek', '--config', 'config/reek.yml', 'lib') or
      fail 'Reek task is not successful'
  end

  task :mutant do
    mutant_jobs = ENV['MUTANT_JOBS']
    mutant_since = mutant_since_revision
    head_revision = `git rev-parse HEAD`.chomp
    arguments = %w[
      bundle exec mutant run
      --include lib
      --require mutant
      --use rspec
      --zombie
    ]
    arguments.concat(['--since', mutant_since]) if mutant_since && mutant_since != head_revision
    arguments.concat(['--jobs', mutant_jobs]) if mutant_jobs
    MUTANT_IGNORE_SUBJECTS.each do |expression|
      arguments.concat(['--ignore-subject', expression])
    end

    arguments.concat(%w[-- Mutant*])

    Kernel.system(*arguments) or fail 'Mutant task is not successful'
  end
end

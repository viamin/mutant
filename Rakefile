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
      bundle exec mutant
      --include lib
      --require mutant
      --use rspec
      --zombie
    ]
    arguments.concat(['--since', mutant_since]) if mutant_since && mutant_since != head_revision
    arguments.concat(['--jobs', mutant_jobs]) if mutant_jobs

    arguments.concat(%w[-- Mutant*])

    Kernel.system(*arguments) or fail 'Mutant task is not successful'
  end
end

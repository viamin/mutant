# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new(:rubocop)

Rake.application.load_imports

task default: :spec

task('metrics:mutant').clear
namespace :metrics do
  task mutant: :coverage do
    mutant_jobs = ENV['MUTANT_JOBS']
    arguments = %w[
      bundle exec mutant
      --include lib
      --since HEAD~1
      --require mutant
      --use rspec
      --zombie
    ]
    arguments.concat(['--jobs', mutant_jobs]) if mutant_jobs

    arguments.concat(%w[-- Mutant*])

    Kernel.system(*arguments) or fail 'Mutant task is not successful'
  end
end

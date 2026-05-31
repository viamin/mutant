# frozen_string_literal: true

require 'bundler/gem_helper'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

Bundler::GemHelper.install_tasks name: 'mutant'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new(:rubocop)

Rake.application.load_imports

task default: :spec

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
    mutant_since = ENV.fetch('MUTANT_SINCE', 'HEAD~1')
    head_revision = `git rev-parse HEAD`.chomp
    arguments = %w[
      bundle exec mutant
      --include lib
      --require mutant
      --use rspec
      --zombie
    ]
    arguments.concat(['--since', mutant_since]) unless mutant_since.empty? || mutant_since == head_revision
    arguments.concat(['--jobs', mutant_jobs]) if mutant_jobs

    arguments.concat(%w[-- Mutant*])

    Kernel.system(*arguments) or fail 'Mutant task is not successful'
  end
end

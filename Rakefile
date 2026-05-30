# frozen_string_literal: true

require 'bundler/gem_helper'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

Bundler::GemHelper.install_tasks name: 'mutant'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new(:rubocop)

Rake.application.load_imports

task default: :spec

def valid_git_revision?(revision)
  return false if revision.to_s.empty?

  Kernel.system(
    'git',
    'rev-parse',
    '--verify',
    "#{revision}^{commit}",
    out: File::NULL,
    err: File::NULL
  )
end

def mutant_since_revision
  revision = ENV['MUTANT_SINCE']
  return revision if valid_git_revision?(revision)

  fallback = 'HEAD~1'
  return fallback if valid_git_revision?(fallback)
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
    arguments = %w[
      bundle exec mutant
      --include lib
      --require mutant
      --use rspec
      --zombie
    ]
    arguments.concat(['--since', mutant_since]) if mutant_since
    arguments.concat(['--jobs', mutant_jobs]) if mutant_jobs

    arguments.concat(%w[-- Mutant*])

    Kernel.system(*arguments) or fail 'Mutant task is not successful'
  end
end

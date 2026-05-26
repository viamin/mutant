# frozen_string_literal: true

require 'devtools'

Devtools.init_rake_tasks

Rake.application.load_imports

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

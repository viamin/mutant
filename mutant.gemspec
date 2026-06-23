# frozen_string_literal: true

require File.expand_path('lib/mutant/version', __dir__)

Gem::Specification.new do |gem|
  gem.name        = 'mutant'
  gem.version     = Mutant::VERSION.dup
  gem.authors     = ['Markus Schirp']
  gem.email       = ['mbj@schirp-dso.com']
  gem.description = 'Mutation testing for ruby'
  gem.summary     = 'Mutation testing tool for ruby under MRI and Rubinius'
  gem.homepage    = 'https://github.com/mbj/mutant'
  gem.license     = 'MIT'
  gem.required_ruby_version = '>= 3.3', '< 4.0'

  gem.require_paths = %w[lib]

  exclusion = `git ls-files -- lib/mutant/{minitest,integration}`.split("\n")

  gem.files            = `git ls-files`.split("\n") - exclusion
  gem.test_files       = `git ls-files -- spec/{unit,integration}`.split("\n")
  gem.extra_rdoc_files = %w[LICENSE]
  gem.executables      = %w[mutant]

  gem.add_runtime_dependency('abstract_type', '~> 0.0.7')
  gem.add_runtime_dependency('adamantium',    '~> 0.2.0')
  gem.add_runtime_dependency('anima',         '~> 0.3.2')
  gem.add_runtime_dependency('ast',           '~> 2.4')
  gem.add_runtime_dependency('concord',       '~> 0.1.6')
  gem.add_runtime_dependency('diff-lcs',      '~> 1.6')
  gem.add_runtime_dependency('equalizer',     '~> 0.0.11')
  gem.add_runtime_dependency('ice_nine',      '~> 0.11.2')
  gem.add_runtime_dependency('memoizable',    '~> 0.4.2')
  gem.add_runtime_dependency('morpher',       '~> 0.4.2')
  gem.add_runtime_dependency('parser',        '~> 3.3.6')
  gem.add_runtime_dependency('procto',        '~> 0.0.3')
  gem.add_runtime_dependency('racc',          '~> 1.8')
  gem.add_runtime_dependency('regexp_parser', '~> 2.10')
  gem.add_runtime_dependency('unparser',      '~> 0.9.0')

  gem.add_development_dependency('base64',    '~> 0.3')
  gem.add_development_dependency('parallel',  '~> 1.27')
  gem.add_development_dependency('rake',      '~> 13.2')
  gem.add_development_dependency('reek')
  gem.add_development_dependency('rspec',     '~> 3.10')
  gem.add_development_dependency('rspec-core','~> 3.10')
  gem.add_development_dependency('rspec-its', '~> 1.3')
  gem.add_development_dependency('rubocop',   '~> 1.50.0')
  gem.add_development_dependency('simplecov', '~> 0.22')
end

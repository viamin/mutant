# frozen_string_literal: true

require 'anima'
require 'mutant'
require 'parallel'
require 'yaml'

# @api private
module MutantSpec
  ROOT = Pathname.new(__FILE__).parent.parent.parent

  # Namespace module for corpus testing
  #
  # rubocop:disable MethodLength
  module Corpus
    TMP                 = ROOT.join('tmp').freeze
    EXCLUDE_GLOB_FORMAT = '{%s}'

    # Not in the docs. Number from chatting with their support.
    # 2 processors allocated per container, 4 processes works well.
    CIRCLE_CI_CONTAINER_PROCESSES = 4

    private_constant(*constants(false))

    # Project under corpus test
    # rubocop:disable ClassLength
    class Project
      MUTEX = Mutex.new

      MUTATION_GENERATION_MESSAGE = 'Total Mutations/Time/Parse-Errors: %s/%0.2fs - %0.2f/s'
      START_MESSAGE               = 'Starting - %s'
      FINISH_MESSAGE              = 'Mutations - %4i - %s'

      DEFAULT_MUTATION_COUNT = 0

      include Adamantium, Anima.new(
        :expected_errors,
        :mutation_coverage,
        :mutation_generation,
        :integration,
        :name,
        :namespace,
        :repo_uri,
        :repo_ref,
        :ruby_glob_pattern,
        :exclude
      )

      # Verify mutation coverage
      #
      # @return [self]
      #   if successful
      #
      # @raise [Exception]
      def verify_mutation_coverage
        checkout
        Dir.chdir(repo_path) do
          with_nested_bundle_environment do
            install_mutant
            relative = ROOT.relative_path_from(repo_path)
            system(
              %W[
                bundle exec ruby #{relative.join('bin', 'mutant')}
                --use #{integration}
                --include lib
                --require #{name}
                #{namespace}*
              ] + concurrency_limits
            )
          end
        end
      end

      # The concurrency limits, if any
      #
      # @return [Array<String>]
      def concurrency_limits
        if ENV.key?('MUTANT_JOBS')
          %W[--jobs #{ENV.fetch('MUTANT_JOBS')}]
        else
          []
        end
      end

      # Verify mutation generation
      #
      # @return [self]
      #   if successful
      #
      # @raise [Exception]
      #   otherwise
      def verify_mutation_generation
        checkout
        start = Mutant::Timer.now

        options = {
          finish:       method(:finish),
          start:        method(:start),
          in_processes: parallel_processes
        }

        total = Parallel.map(effective_ruby_paths, options, &method(:check_generation))
          .inject(DEFAULT_MUTATION_COUNT, :+)

        took = Mutant::Timer.now - start
        puts MUTATION_GENERATION_MESSAGE % [total, took, total / took]
        self
      end

      # Checkout repository
      #
      # @return [self]
      def checkout
        return self if noinstall?
        TMP.mkdir unless TMP.directory?

        if repo_path.exist?
          Dir.chdir(repo_path) do
            system(%w[git fetch origin])
            system(%w[git reset --hard])
            system(%w[git clean -f -d -x])
          end
        else
          system(%W[git clone #{repo_uri} #{repo_path}])
        end

        Dir.chdir(repo_path) do
          system(%W[git checkout #{repo_ref}])
          system(%w[git reset --hard])
          system(%w[git clean -f -d -x])
        end

        self
      end
      memoize :checkout

    private

      def relax_mutant_version_constraints
        Dir[repo_path.join('*.gemspec')].each do |gemspec_path|
          content = File.read(gemspec_path)
          content = content.gsub(
            /add_development_dependency\('mutant[^']*',\s*'~> [^']*'\)/
          ) do |match|
            match.sub(/'~> [^']*'/, "'>= 0'")
          end
          if integration == 'minitest'
            content = content.gsub(
              /add_development_dependency\('minitest',\s*'[^']*'\)/,
              "add_development_dependency('minitest', '>= 0')"
            )
          end
          File.write(gemspec_path, content)
        end
      end

      # Count mutations and check error results against whitelist
      #
      # @param path [Pathname] path responsible for exception
      #
      # @return [Integer] mutations generated
      def check_generation(path)
        relative_path = path.relative_path_from(repo_path)

        node = Mutant::PARSER_CLASS.parse(path.read)
        fail "Cannot parse: #{path}" unless node

        mutations = Mutant::Mutator.mutate(node)

        mutations.each do |mutation|
          check_generation_invariants(node, mutation)
        end

        expected_errors.assert_success(relative_path)

        mutations.length
      rescue Exception => exception # rubocop:disable Lint/RescueException
        expected_errors.assert_error(relative_path, exception)

        DEFAULT_MUTATION_COUNT
      end

      # Check generation invariants
      #
      # @param [Parser::AST::Node] original
      # @param [Parser::AST::Node] mutation
      #
      # @return [undefined]
      #
      # @raise [Exception]
      def check_generation_invariants(original, mutation)
        return unless ENV['MUTANT_CORPUS_EXPENSIVE']

        original_source = Unparser.unparse(original)
        mutation_source = Unparser.unparse(mutation)

        Mutant::Diff.build(original_source, mutation_source) and return

        fail Mutant::Reporter::CLI::NO_DIFF_MESSAGE % [
          original_source,
          original.inspect,
          mutation_source,
          mutation.inspect
        ]
      end

      # Install mutant
      #
      # @return [undefined]
      def install_mutant
        return if noinstall?
        relative = ROOT.relative_path_from(repo_path)
        repo_path.join('Gemfile').open('w') do |file|
          file << "# frozen_string_literal: true\n"
          file << "source 'https://rubygems.org'\n"
          file << "gemspec\n"
          file << "gem 'mutant', path: '#{relative}'\n"
          case integration
          when 'minitest'
            file << "gem 'mutant-minitest', path: '#{relative}'\n"
          when 'rspec'
            file << "gem 'mutant-rspec', path: '#{relative}'\n"
          end
          file << "eval_gemfile File.expand_path('#{relative.join('Gemfile.shared')}')\n"
        end
        relax_mutant_version_constraints
        lockfile = repo_path.join('Gemfile.lock')
        lockfile.delete if lockfile.exist?
        bundle_dir = repo_path.join('.bundle')
        bundle_dir.mkdir unless bundle_dir.directory?
        bundle_dir.join('config').write(<<~YAML)
          ---
          BUNDLE_PATH: "#{ROOT.join('vendor', 'bundle')}"
        YAML
        system(%w[bundle install])
      end

      # Run nested bundler commands without leaking the parent Gemfile while
      # preserving the bundle path selected by the outer process.
      #
      # @return [Object]
      def with_nested_bundle_environment
        preserved = bundler_environment_overrides

        Bundler.with_unbundled_env do
          preserved.each { |key, value| ENV[key] = value }
          yield
        ensure
          preserved.each_key { |key| ENV.delete(key) }
        end
      end

      # Bundler environment variables needed by nested bundle commands.
      #
      # @return [Hash<String, String>]
      def bundler_environment_overrides
        path = Bundler.settings[:path]
        value = ENV['BUNDLE_PATH'] || path && File.expand_path(path, ROOT)
        result = {}
        result['BUNDLE_PATH'] = value if value
        result
      end

      # The effective ruby file paths
      #
      # @return [Array<Pathname>]
      def effective_ruby_paths
        Pathname
          .glob(repo_path.join(ruby_glob_pattern))
          .sort_by(&:size)
          .reverse
          .reject { |path| exclude.include?(path.relative_path_from(repo_path).to_s) }
      end

      # Number of parallel processes to use
      #
      # @return [Integer]
      def parallel_processes
        if ENV.key?('CI')
          CIRCLE_CI_CONTAINER_PROCESSES
        else
          Etc.nprocessors
        end
      end

      # Repository path
      #
      # @return [Pathname]
      def repo_path
        TMP.join(name)
      end

      # Test if installation should be skipped
      #
      # @return [Boolean]
      def noinstall?
        ENV.key?('NOINSTALL')
      end

      # Print start progress
      #
      # @param [Pathname] path
      # @param [Integer] _index
      #
      # @return [undefined]
      #
      def start(path, _index)
        MUTEX.synchronize do
          puts START_MESSAGE % path
        end
      end

      # Print finish progress
      #
      # @param [Pathname] path
      # @param [Integer] _index
      # @param [Integer] count
      #
      # @return [undefined]
      #
      def finish(path, _index, count)
        MUTEX.synchronize do
          puts FINISH_MESSAGE % [count, path]
        end
      end

      # Helper method to execute system commands
      #
      # @param [Array<String>] arguments
      #
      # rubocop:disable GuardClause - guard clause without else does not make sense
      def system(arguments)
        output = IO.popen(arguments, err: %i[child out], &:read)
        status = Process.last_status || $CHILD_STATUS
        return if status&.success?

        if block_given?
          yield
        else
          raise(
            "System command failed!: #{arguments.join(' ')}\n" \
            "Status: #{status.inspect}\n" \
            "Output:\n#{output}"
          )
        end
      end

      # Mapping of files which we expect to cause errors during mutation generation
      class ErrorWhitelist
        class UnnecessaryExpectation < StandardError
          MESSAGE = 'Expected to encounter %s while mutating "%s"'

          def initialize(*error_info)
            super(MESSAGE % error_info)
          end
        end # UnnecessaryExpectation

        include Concord.new(:map), Adamantium

        # Assert that we expect to encounter the provided exception for this path
        #
        # @param path [Pathname]
        # @param exception [Exception]
        #
        # @raise provided exception if we are not expecting this error
        #
        # This method is reraising exceptions but rubocop can't tell
        # rubocop:disable Style/SignalException
        #
        # @return [undefined]
        def assert_error(path, exception)
          original_error = exception.cause || exception

          raise exception unless map.fetch(original_error.inspect, []).include?(path)
        end

        # Assert that we expect to not encounter an error for the specified path
        #
        # @param path [Pathname]
        #
        # @raise [UnnecessaryExpectation] if we are expecting an exception for this path
        #
        # @return [undefined]
        def assert_success(path)
          map.each do |error, paths|
            fail UnnecessaryExpectation.new(error, path) if paths.include?(path)
          end
        end

        # Return representation as hash
        #
        # @note this method is necessary for morpher loader to be invertible
        #
        # @return [Hash{Pathname => String}]
        def to_h
          map
        end
      end # ErrorWhitelist

      def self.load(raw_projects)
        raw_projects.map do |attributes|
          Project.new(
            expected_errors:     ErrorWhitelist.new(
              attributes.fetch('expected_errors').to_h do |error, paths|
                [error, paths.map(&Pathname.method(:new))]
              end
            ),
            mutation_coverage:   attributes.fetch('mutation_coverage'),
            mutation_generation: attributes.fetch('mutation_generation'),
            integration:         attributes.fetch('integration'),
            name:                attributes.fetch('name'),
            namespace:           attributes.fetch('namespace'),
            repo_uri:            attributes.fetch('repo_uri'),
            repo_ref:            attributes.fetch('repo_ref'),
            ruby_glob_pattern:   attributes.fetch('ruby_glob_pattern'),
            exclude:             attributes.fetch('exclude')
          )
        end
      end

      ALL = load(YAML.load_file(ROOT.join('spec', 'integrations.yml')))
    end # Project
  end # Corpus
end # MutantSpec

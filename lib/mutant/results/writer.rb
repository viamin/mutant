# frozen_string_literal: true

module Mutant
  module Results
    class Writer
      include Adamantium::Flat, Concord.new(:result), Procto.call(:call)

      HEAD             = 'HEAD'
      SHORT_SHA_LENGTH = 7
      FILENAME_FORMAT  = '%Y%m%dT%H%M%SZ'
      private_constant(*constants(false))

      def call
        time = Time.now.getutc

        FileUtils.mkdir_p(results_dir)
        path = results_dir.join("#{time.strftime(FILENAME_FORMAT)}-#{short_sha}-#{SecureRandom.hex(6)}.yml")
        path.write(YAML.dump(Document.call(result, git_ref, time.iso8601)))
        path
      end

    private

      def short_sha
        git_ref[0, SHORT_SHA_LENGTH]
      end
      memoize :short_sha

      def git_ref
        stdout, status = config.open3.capture2('git', 'rev-parse', HEAD, binmode: true)
        repository_error('Command ["git", "rev-parse", "HEAD"] failed!') unless status.success?

        stdout.chomp
      end
      memoize :git_ref

      def results_dir
        config.pathname.new(config.results_dir)
      end
      memoize :results_dir

      def config
        result.env.config
      end

      def repository_error(message)
        fail Repository::RepositoryError, message
      end
    end
  end
end

# frozen_string_literal: true

require 'open3'

module Mutant
  class SinceRevisionResolver
    BASE_REFS = %w[origin/main main].freeze
    HEAD_PREDECESSOR = 'HEAD~1'

    def initialize(capture, kernel)
      @capture = capture
      @kernel = kernel
    end

    def call(revision)
      return revision if valid_git_revision?(revision)

      resolve_merge_base || head_predecessor
    end

  private

    def resolve_merge_base
      BASE_REFS.each do |base_ref|
        merge_base = merge_base_revision(base_ref)

        return merge_base if merge_base
      end

      nil
    end

    def merge_base_revision(base_ref)
      return unless valid_git_revision?(base_ref)

      stdout, status = @capture.capture2('git', 'merge-base', 'HEAD', base_ref, binmode: true)
      return unless status.success?

      revision = stdout.strip

      revision if valid_git_revision?(revision)
    end

    def head_predecessor
      HEAD_PREDECESSOR if valid_git_revision?(HEAD_PREDECESSOR)
    end

    def valid_git_revision?(revision)
      return false if revision.to_s.empty?

      @kernel.system(
        'git',
        'rev-parse',
        '--verify',
        "#{revision}^{commit}",
        out: File::NULL,
        err: File::NULL
      )
    end
  end
end

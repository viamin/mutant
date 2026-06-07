# frozen_string_literal: true

module Mutant
  class Matcher
    # Subject filter based on source path glob patterns
    class SourcePathFilter
      include Adamantium, Anima.new(:pathname, :pattern, :root)

      MATCH_FLAGS = File::FNM_EXTGLOB | File::FNM_PATHNAME

      # Test if subject source path should be included
      #
      # @param [Subject] subject
      #
      # @return [Boolean]
      def call(subject)
        !File.fnmatch?(pattern, relative_path(subject.source_path), MATCH_FLAGS)
      end

    private

      # Relative path to source root
      #
      # @param [Pathname] source_path
      #
      # @return [String]
      def relative_path(source_path)
        pathname
          .new(source_path)
          .relative_path_from(root)
          .to_s
      rescue ArgumentError
        source_path.to_s
      end
    end # SourcePathFilter
  end # Matcher
end # Mutant

# frozen_string_literal: true

module Mutant
  # An AST Parser
  class Parser
    include Adamantium::Mutable, Equalizer.new

    # Initialize object
    #
    # @return [undefined]
    def initialize
      @cache = {}
    end

    # Parse path into AST
    #
    # @param [Pathname] path
    #
    # @return [AST::Node]
    def call(path)
      @cache[path] ||= Unparser.parser.parse_with_comments(buffer(path)).first
    end

  private

    # Source buffer retaining the filename for parser diagnostics
    #
    # @param [Pathname] path
    #
    # @return [Parser::Source::Buffer]
    def buffer(path)
      ::Parser::Source::Buffer.new(path.to_s, source: path.read)
    end

  end # Parser
end # Mutant

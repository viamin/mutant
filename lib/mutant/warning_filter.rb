# frozen_string_literal: true

module Mutant
  # Stream filter for warnings
  class WarningFilter
    include Equalizer.new(:target)

    WARNING_RE = /(?:.+):(?:\d+): warning: (?:.+)/.freeze

    # Initialize object
    #
    # @param [#write] target
    #
    # @return [undefined]
    def initialize(target)
      @target   = target
      @warnings = []
    end

    # Warnings captured by filter
    #
    # @return [Array<String>]
    attr_reader :warnings

    # Target stream to capture warnings on
    #
    # @return [#write] target
    #
    # @return [undefined]
    attr_reader :target
    protected :target

    # Write message to target filtering warnings
    #
    # @param [String] message
    #
    # @return [self]
    def write(message)
      warning, non_warning = message.split("\n", -1).partition { |line| WARNING_RE.match?(line) }

      append_warnings(warning)
      write_non_warning_lines(non_warning)

      self
    end

    # Use warning filter during block execution
    #
    # @return [Array<String>]
    def self.use
      original_stderr = $stderr
      $stderr = filter = new(original_stderr)

      yield
      filter.warnings
    ensure
      $stderr = original_stderr
    end

  private

    def append_warnings(lines)
      lines.each { |line| warnings << "#{line}\n" }
    end

    def write_non_warning_lines(lines)
      return if lines.all?(&:empty?)

      target << lines.join("\n")
    end

  end # WarningFilter
end # Mutant

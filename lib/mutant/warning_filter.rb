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
      non_warning = []
      warning = []
      message.split("\n", -1).each do |line|
        (WARNING_RE.match?(line) ? warning : non_warning) << line
      end
      warning.each { |line| warnings << "#{line}\n" }
      target.write(non_warning.join("\n")) unless non_warning.all?(&:empty?)

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

  end # WarningFilter
end # Mutant

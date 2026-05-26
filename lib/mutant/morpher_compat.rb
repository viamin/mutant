# frozen_string_literal: true

module Morpher
  module Evaluator
    module Predicate
      class Negation
        include Concord.new(:predicate)

        def call(input)
          !predicate.call(input)
        end
      end

      module Boolean
        class And
          include Concord.new(:predicates)

          def call(input)
            predicates.all? { |predicate| predicate.call(input) }
          end
        end

        class Or
          include Concord.new(:predicates)

          def call(input)
            predicates.any? { |predicate| predicate.call(input) }
          end
        end

        Negation = Predicate::Negation
      end
    end
  end

  def self.compile(node)
    type = node.type
    children = node.children

    case type
    when :and
      Evaluator::Predicate::Boolean::And.new(children.map(&method(:compile)))
    when :or
      Evaluator::Predicate::Boolean::Or.new(children.map(&method(:compile)))
    when :negate
      Evaluator::Predicate::Negation.new(compile(children.fetch(0)))
    else
      raise ArgumentError, "Unsupported morpher compatibility node: #{node.inspect}"
    end
  end
end

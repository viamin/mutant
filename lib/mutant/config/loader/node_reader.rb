# frozen_string_literal: true

module Mutant
  class Config
    class Loader
      class NodeReader
        include Adamantium, Concord.new(:path)

        def mapping(node, context, allowed_keys)
          fail_invalid_type(node, context, 'mapping') unless node.instance_of?(Psych::Nodes::Mapping)

          node.children.each_slice(2).map do |key_node, value_node|
            key = string(key_node, context)
            fail_unknown_key(key_node, context, key) unless allowed_keys.include?(key)
            [key, value_node]
          end
        end

        def string_list(node, context)
          fail_invalid_type(node, context, 'sequence') unless node.instance_of?(Psych::Nodes::Sequence)

          node.children.map { |child| string(child, context) }
        end

        def string_hash(node, context)
          fail_invalid_type(node, context, 'mapping') unless node.instance_of?(Psych::Nodes::Mapping)

          node.children.each_slice(2).each_with_object({}) do |(key_node, value_node), hash|
            key = string(key_node, context)
            hash[key] = string(value_node, context + [key])
          end
        end

        def string(node, context)
          scalar(node, context, String)
        end

        def integer(node, context)
          scalar(node, context, Integer)
        end

        def boolean(node, context)
          value = to_ruby(node)
          return value if [TrueClass, FalseClass].any? { |klass| value.instance_of?(klass) }

          fail_invalid_scalar(node, context, 'Boolean')
        end

      private

        def scalar(node, context, expected_class)
          value = to_ruby(node)
          return value if value.instance_of?(expected_class)

          fail_invalid_scalar(node, context, expected_class.name)
        end

        def fail_invalid_scalar(node, context, expected)
          fail Error, "Invalid value for #{context.join('.')} at #{location(node)}: expected #{expected.inspect}"
        end

        def fail_invalid_type(node, context, expected)
          fail Error, "Invalid value for #{context.join('.')} at #{location(node)}: expected #{expected}"
        end

        def fail_unknown_key(node, context, key)
          fail Error, "Unknown config key #{(context + [key]).join('.').inspect} at #{location(node)}"
        end

        def location(node)
          "#{path}:#{node.start_line + 1}"
        end

        def to_ruby(node)
          return node.value if node.quoted

          raw = node.value

          case raw
          when 'true'  then true
          when 'false' then false
          else              Integer(raw)
          end
        rescue ArgumentError
          raw
        end
      end
    end
  end
end

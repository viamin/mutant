module ExactMatcherFixtures
    module InnerWrapper
      def execute
        [:inner, super]
      end
    end

    module OuterWrapper
      def execute
        [:outer, super]
      end
    end

    class Target
      prepend InnerWrapper
      prepend OuterWrapper

      def execute
        :body
      end

      private

      def private_execute
        :private_body
      end
    end

    class Parent
      def inherited_execute
        :inherited_body
      end
    end

    class Child < Parent
    end
end

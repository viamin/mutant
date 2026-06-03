module TestApp
  module SubjectMatchers
    module Prepended
      def prepended_instance
        :prepended_instance
      end
    end

    class Root
      prepend Prepended

      def alpha
        :alpha
      end

      def self.beta
        :beta
      end
    end

    module Nested
      class Child
        def gamma
          :gamma
        end
      end
    end
  end
end

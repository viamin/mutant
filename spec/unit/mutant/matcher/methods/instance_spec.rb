# frozen_string_literal: true

RSpec.describe Mutant::Matcher::Methods::Instance, '#call' do
  let(:object) { described_class.new(class_under_test) }
  let(:env)    { Fixtures::TEST_ENV                    }

  let(:class_under_test) do
    parent = Module.new do
      def inherited_method; end
    end

    wrapper_a = Module.new do
      def method_a
        super
        :wrapper_a
      end

      def method_b
        super
        :wrapper_a
      end
    end

    wrapper_b = Module.new do
      def method_a
        super
        :wrapper_b
      end

      def method_b
        super
        :wrapper_b
      end
    end

    Class.new do
      include parent
      prepend wrapper_a
      prepend wrapper_b

      def method_a; end

    protected

      def method_b; end

    private

      def method_c; end
    end
  end

  let(:subject_a) { instance_double(Mutant::Subject) }
  let(:subject_b) { instance_double(Mutant::Subject) }
  let(:subject_c) { instance_double(Mutant::Subject) }
  let(:subjects)  { [subject_a, subject_b, subject_c] }

  def class_implementation(method_name)
    method = class_under_test.instance_method(method_name)
    method = method.super_method until method.owner.equal?(class_under_test)
    method
  end

  before do
    {
      method_a: subject_a,
      method_b: subject_b,
      method_c: subject_c
    }.each do |method, subject|
      matcher = instance_double(Mutant::Matcher)
      expect(matcher).to receive(:call).with(env).and_return([subject])

      expect(Mutant::Matcher::Method::Instance).to receive(:new)
        .with(class_under_test, class_implementation(method))
        .and_return(matcher)
    end
  end

  it 'returns subjects for directly defined public, protected and private methods behind multiple prepends' do
    expect(object.call(env)).to eql(subjects)
  end
end

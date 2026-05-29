# frozen_string_literal: true

RSpec.describe Mutant::Expression::Namespace::Exact do
  let(:object) { parse_expression(input) }
  let(:input)  { 'TestApp::Literal'      }

  describe '#matcher' do
    subject { object.matcher }

    it { should eql(Mutant::Matcher::Namespace.new(object)) }
  end

  describe '#match_length' do
    subject { object.match_length(other) }

    context 'when other is an equivalent expression' do
      let(:other) { parse_expression(object.syntax) }

      it { should be(object.syntax.length) }
    end

    context 'when other is an unequivalent expression' do
      let(:other) { parse_expression('Foo*') }

      it { should be(0) }
    end

    context 'when other expression describes a nested namespace' do
      let(:other) { parse_expression('TestApp::Literal::Deep') }

      it { should be(object.syntax.length) }
    end

    context 'when other expression describes a singleton method' do
      let(:other) { parse_expression('TestApp::Literal.foo') }

      it { should be(object.syntax.length) }
    end

    context 'when other expression describes an instance method' do
      let(:other) { parse_expression('TestApp::Literal#foo') }

      it { should be(object.syntax.length) }
    end
  end
end

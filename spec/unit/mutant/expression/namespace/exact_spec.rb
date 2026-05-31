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

    context 'when other expression describes adjacent namespace' do
      let(:other) { parse_expression('TestApp::LiteralFoo') }

      it { should be(0) }
    end

    context 'when other expression describes a method on an adjacent namespace' do
      let(:other) { parse_expression('TestApp::LiteralFoo.bar') }

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

  describe '#prefix_match_length' do
    subject { object.send(:prefix_match_length, expression) }

    let(:expression) { instance_double(Mutant::Expression, syntax: syntax) }

    context 'when the namespace syntax matches exactly' do
      let(:syntax) { object.syntax }

      it { should be(object.syntax.length) }
    end

    context 'when the namespace is followed by a single colon' do
      let(:syntax) { 'TestApp::Literal:Deep' }

      it { should be(0) }
    end

    context 'when a colon appears later in the adjacent namespace' do
      let(:syntax) { 'TestApp::LiteralDeep:' }

      it { should be(0) }
    end

    context 'when only the second character after the namespace is a colon' do
      let(:syntax) { 'TestApp::LiteralX:Deep' }

      it { should be(0) }
    end

    context 'when the namespace is followed by a scope operator' do
      let(:syntax) { 'TestApp::Literal::Deep' }

      it { should be(object.syntax.length) }
    end

    context 'when the namespace contains regexp metacharacters' do
      let(:object) { described_class.new(scope_name: 'Test.App') }
      let(:syntax) { 'TestXApp::Deep' }

      it { should be(0) }
    end
  end
end

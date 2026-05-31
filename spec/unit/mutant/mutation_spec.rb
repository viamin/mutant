# frozen_string_literal: true

RSpec.describe Mutant::Mutation do
  let(:mutation_class) do
    Class.new(Mutant::Mutation) do
      const_set(:SYMBOL, 'test')
      const_set(:TEST_PASS_SUCCESS, true)
    end
  end

  let(:context) { instance_double(Mutant::Context) }

  let(:object) do
    mutation_class.new(mutation_subject, Mutant::AST::Nodes::N_NIL)
  end

  let(:mutation_subject) do
    instance_double(
      Mutant::Subject,
      identification: 'subject',
      context:        context,
      source:         'original'
    )
  end

  describe '#insert' do
    subject { object.insert(kernel) }

    let(:expected_source) { '1'                     }
    let(:kernel)          { instance_double(Kernel) }
    let(:root_node)       { s(:int, 1)              }

    before do
      expect(context).to receive(:root)
        .with(object.node)
        .and_return(root_node)

      expect(mutation_subject).to receive(:prepare)
        .ordered
        .and_return(mutation_subject)

      expect(Mutant::Loader).to receive(:call)
        .ordered
        .with(
          binding: TOPLEVEL_BINDING,
          kernel:  kernel,
          source:  expected_source,
          subject: mutation_subject
        )
        .and_return(Mutant::Loader)
    end

    it_should_behave_like 'a command method'
  end

  describe '#code' do
    subject { object.code }

    it { should eql('8771a') }

    it_should_behave_like 'an idempotent method'
  end

  describe '#original_source' do
    subject { object.original_source }

    it { should eql('original') }

    it_should_behave_like 'an idempotent method'
  end

  describe '#source' do
    subject { object.source }

    it { should eql('nil') }

    it_should_behave_like 'an idempotent method'
  end

  describe '#monkeypatch' do
    subject { object.monkeypatch }

    let(:root_node) { s(:int, 1) }

    before do
      expect(context).to receive(:root).with(object.node).and_return(root_node)
    end

    it { should eql('1') }

    it_should_behave_like 'an idempotent method'
  end

  describe '.success?' do
    subject { mutation_class.success?(test_result) }

    let(:test_result) do
      instance_double(
        Mutant::Result::Test,
        passed: passed
      )
    end

    context 'on mutation with positive pass expectation' do
      context 'when Result::Test#passed equals expectation' do
        let(:passed) { true }

        it { should be(true) }
      end

      context 'when Result::Test#passed NOT equals expectation' do
        let(:passed) { false }

        it { should be(false) }
      end
    end

    context 'on mutation with negative pass expectation' do
      let(:mutation_class) do
        Class.new(super()) do
          const_set(:TEST_PASS_SUCCESS, false)
        end
      end

      context 'when Result::Test#passed equals expectation' do
        let(:passed) { true }

        it { should be(false) }
      end

      context 'when Result::Test#passed NOT equals expectation' do
        let(:passed) { false }

        it { should be(true) }
      end
    end
  end

  describe '.exception_success?' do
    subject { mutation_class.exception_success?(exception) }

    let(:exception) { SyntaxError.new('broken mutation') }

    context 'on mutation with positive pass expectation' do
      it { should be(false) }
    end

    context 'on mutation with negative pass expectation' do
      let(:mutation_class) do
        Class.new(super()) do
          const_set(:TEST_PASS_SUCCESS, false)
        end
      end

      context 'with mutation-induced exceptions' do
        it { should be(true) }
      end

      context 'with direct mutation-induced exceptions' do
        signal_exception =
          Class.new(SignalException) do
            def initialize
              super('TERM')
            end
          end.new

        {
          Interrupt.new => 'interrupt',
          NameError.new('missing constant') => 'name error',
          Class.new(NameError).new('nested missing constant') => 'name error subclass',
          Class.new(ScriptError).new('script error') => 'script error',
          signal_exception => 'signal exception',
          Class.new(SystemExit).new(1) => 'system exit'
        }.each do |mutation_exception, description|
          context "with #{description}" do
            let(:exception) { mutation_exception }

            it { should be(true) }
          end
        end
      end

      context 'with a serialized mutation-induced exception' do
        {
          'Interrupt'       => '#<Interrupt: Interrupt>',
          'NameError'       => '#<NameError: missing constant>',
          'NoMethodError'   => '#<NoMethodError: undefined method `foo`>',
          'ScriptError'     => '#<ScriptError: script error>',
          'SignalException' => '#<SignalException: SIGTERM>',
          'SyntaxError'     => '#<SyntaxError: broken mutation>',
          'SystemExit'      => '#<SystemExit: exit>'
        }.each do |exception_class_name, inspection|
          context "with #{exception_class_name}" do
            let(:exception) do
              Mutant::Isolation::Result::SerializedException.new(
                Mutant::EMPTY_ARRAY,
                exception_class_name,
                inspection
              )
            end

            it { should be(true) }
          end
        end
      end

      context 'with a non-mutation exception' do
        let(:exception) { RuntimeError.new('app bug') }

        it { should be(false) }
      end

      context 'with a direct non-mutation exception' do
        let(:exception) do
          Class.new(FrozenError).new('generic exception')
        end

        it { should be(false) }
      end

      context 'with a serialized non-mutation exception' do
        let(:exception) do
          Mutant::Isolation::Result::SerializedException.new(
            Mutant::EMPTY_ARRAY,
            'RuntimeError',
            '#<RuntimeError: app bug>'
          )
        end

        it { should be(false) }
      end
    end
  end

  describe '#identification' do

    subject { object.identification }

    it { should eql('test:subject:8771a') }

    it_should_behave_like 'an idempotent method'
  end
end

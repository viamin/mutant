# frozen_string_literal: true

RSpec.describe Mutant::WarningFilter do
  before do
    if RUBY_ENGINE.eql?('rbx')
      skip 'Disabled because expected warnings are from MRI'
    end
  end

  let(:object) { described_class.new(target) }

  let(:target) do
    acc = writes
    Module.new do
      define_singleton_method(:write, &acc.method(:<<))
      define_singleton_method(:<<) do |message|
        acc << message
        self
      end
    end
  end

  let(:writes) { [] }

  describe '#write' do
    subject { object.write(message) }

    context 'when writing a non warning message' do
      let(:message) { 'foo' }

      it 'writes message' do
        expect { subject }.to change { writes }.from([]).to([message])
      end

      it 'does not capture warning' do
        subject
        expect(subject.warnings).to eql([])
      end
    end

    context 'when writing a warning message' do
      let(:message) { "test.rb:1: warning: some warning\n" }

      it 'captures warning' do
        expect { subject }.to change { object.warnings }.from([]).to([message])
      end

      it 'does not write message' do
        subject
        expect(writes).to eql([])
      end
    end

    context 'when writing mixed warning and non warning lines' do
      let(:message) do
        <<~MESSAGE
          foo
          test.rb:1: warning: some warning
          bar
        MESSAGE
      end

      it 'captures warning lines and preserves non warning separators' do
        expect(object).to receive(:write).once.and_call_original
        expect { subject }.to change { object.warnings }.from([]).to(["test.rb:1: warning: some warning\n"])
        expect(writes).to eql(["foo\nbar\n"])
      end
    end
  end

  describe '.use' do
    let(:object) { described_class }

    it 'executes block with warning filter enabled' do
      found = false
      object.use do
        found = $stderr.instance_of?(described_class)
      end
      expect(found).to be(true)
    end

    it 'resets to original stderr after execution with exception ' do
      original = $stderr
      begin
        object.use { fail }
      rescue
        :make_rubo_cop_happy
      end
      expect($stderr).to be(original)
    end

    it 'returns warnings generated within block' do
      warnings = object.use do
        # rubocop:disable Style/EvalWithLocation
        eval(<<-RUBY)
          Class.new do
            def foo
            end

            def foo
            end
          end
        RUBY
      end
      expect(warnings.length).to be(2)
      expect(warnings[0]).to match(/warning: method redefined/)
      expect(warnings[1]).to match(/warning: previous definition/)
    end

    it 'passes through non warning writes' do
      expect($stderr).to receive(:<<).with('foo')
      object.use do
        $stderr.write('foo')
      end
    end

    it 'resets to original stderr after execution' do
      original = $stderr
      object.use {}
      expect($stderr).to be(original)
    end
  end
end

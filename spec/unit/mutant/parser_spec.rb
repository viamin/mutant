# frozen_string_literal: true

RSpec.describe Mutant::Parser do
  let(:object) { described_class.new }
  let(:modern_fixture_path) { Pathname.new(__dir__).join('../../fixtures/modern_syntax.rb').expand_path }

  describe '#call' do
    let(:path) { instance_double(Pathname) }

    subject { object.call(path) }

    before do
      expect(path).to receive(:read)
        .with(no_args)
        .and_return(':source')
    end

    it 'returns parsed source' do
      expect(subject).to have_attributes(
        children: [:source],
        loc:      have_attributes(expression: have_attributes(source_buffer: have_attributes(name: path.to_s)))
      )
    end

    it 'is idempotent' do
      source = object.call(path)
      expect(subject).to be(source)
    end
  end

  describe 'modern Ruby syntax fixtures' do
    it 'parses without raising' do
      expect { object.call(modern_fixture_path) }.not_to raise_error
    end

    it 'preserves the fixture path for source locations' do
      expect(object.call(modern_fixture_path).loc.expression.source_buffer.name).to eql(modern_fixture_path.to_s)
    end
  end

  describe 'binary string literals' do
    let(:source) do
      <<~'RUBY'
        # encoding: utf-8
        class BinaryFixture
          def binary
            "Done \xFF".b
          end

          def unicode
            "café ✓"
          end
        end
      RUBY
    end

    let(:path) do
      Tempfile.new(['binary-fixture', '.rb']).tap do |file|
        file.write(source)
        file.close
      end
    end

    after do
      path.unlink
    end

    it 'preserves binary bytes and Unicode strings through a parse/unparse round trip' do
      round_tripped_source = Unparser.unparse(object.call(Pathname.new(path.path)))
      fixture_module = Module.new

      fixture_module.module_eval(round_tripped_source)
      fixture = fixture_module.const_get(:BinaryFixture).new

      expect(fixture.binary.bytes).to eql([68, 111, 110, 101, 32, 255])
      expect(fixture.binary.encoding).to eql(Encoding::BINARY)
      expect(fixture.unicode).to eql('café ✓')
      expect(fixture.unicode.encoding).to eql(Encoding::UTF_8)
    end
  end

  describe 'invalid source' do
    let(:path) do
      Tempfile.new(['invalid-fixture', '.rb']).tap do |file|
        file.write('class')
        file.close
      end
    end

    after do
      path.unlink
    end

    it 'reports the source filename and location' do
      expect { object.call(Pathname.new(path.path)) }.to raise_error(Parser::SyntaxError) do |error|
        expect(error.diagnostic.render.first).to start_with("#{path.path}:1:")
      end
    end
  end
end

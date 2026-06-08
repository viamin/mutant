# frozen_string_literal: true

RSpec.describe Mutant::Meta::Example::Documentation do
  around do |example|
    Dir.mktmpdir do |directory|
      @tmpdir = Pathname.new(directory)
      example.run
    end
  end

  describe '.render' do
    subject(:render) { described_class.render }

    let(:path) { Pathname.new('docs/mutators.md') }

    it 'matches the checked-in mutator documentation' do
      expect(render).to eql(path.read)
    end
  end

  describe '.relative_meta_path' do
    subject(:relative_meta_path) { described_class.send(:relative_meta_path, example) }

    let(:example) do
      instance_double(Mutant::Meta::Example, file: file)
    end

    context 'when the file lives under meta' do
      let(:file) { described_class::ROOT_PATH.join('meta/operators/example.rb').to_s }

      it 'returns the normalized meta-relative path' do
        expect(relative_meta_path).to eql('meta/operators/example.rb')
      end
    end

    context 'when the file does not live under meta' do
      let(:file) { described_class::ROOT_PATH.parent.join('tmp/example.rb').to_s }

      it 'rejects the path' do
        expect { relative_meta_path }
          .to raise_error(ArgumentError, %r{\AExample file is outside .*/meta: .*/tmp/example\.rb\z})
      end
    end

    context 'when the file only shares the meta prefix' do
      let(:file) { described_class::ROOT_PATH.join('meta2/example.rb').to_s }

      it 'rejects the path' do
        expect { relative_meta_path }
          .to raise_error(ArgumentError, %r{\AExample file is outside .*/meta: .*/meta2/example\.rb\z})
      end
    end

    context 'when the file has already been resolved outside meta' do
      let(:file) { @tmpdir.join('external.rb').to_s }

      before do
        Pathname.new(file).write('# external')
      end

      it 'rejects the path' do
        expect { relative_meta_path }
          .to raise_error(ArgumentError, %r{\AExample file is outside .*/meta: .*/external\.rb\z})
      end
    end
  end
end

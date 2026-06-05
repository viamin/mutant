# frozen_string_literal: true

RSpec.describe Mutant::Meta::Example::Documentation do
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
      let(:file) { '/workspace/meta/operators/example.rb' }

      it 'returns the normalized meta-relative path' do
        expect(relative_meta_path).to eql('meta/operators/example.rb')
      end
    end

    context 'when the file does not live under meta' do
      let(:file) { '../../tmp/example.rb' }

      it 'falls back to the basename under meta' do
        expect(relative_meta_path).to eql('meta/example.rb')
      end
    end
  end
end

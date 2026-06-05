# frozen_string_literal: true

RSpec.describe Mutant::Matcher::SourcePathFilter do
  let(:root)    { Pathname.new('/app') }
  let(:object)  { described_class.new(pathname: Pathname, pattern: pattern, root: root) }
  let(:pattern) { 'app/admin/**/*.rb' }

  describe '#call' do
    subject { object.call(subject_instance) }

    let(:subject_instance) do
      instance_double(
        Mutant::Subject,
        source_path: source_path
      )
    end

    context 'when source path matches ignore glob' do
      let(:source_path) { Pathname.new('/app/app/admin/users/show.rb') }

      it { should be(false) }
    end

    context 'when source path does not match ignore glob' do
      let(:source_path) { Pathname.new('/app/app/models/user.rb') }

      it { should be(true) }
    end

    context 'when source path is outside the configured root' do
      let(:source_path) { Pathname.new('/tmp/app/admin/users/show.rb') }

      it { should be(true) }
    end

    it 'matches using the configured file glob flags' do
      expect(File).to receive(:fnmatch?)
        .with(pattern, 'app/admin/users/show.rb', described_class::MATCH_FLAGS)
        .and_return(true)

      object.call(
        instance_double(
          Mutant::Subject,
          source_path: Pathname.new('/app/app/admin/users/show.rb')
        )
      )
    end
  end

  describe 'MATCH_FLAGS' do
    subject { described_class::MATCH_FLAGS }

    it 'combines extglob and pathname flags' do
      expect(subject).to eql(File::FNM_EXTGLOB | File::FNM_PATHNAME)
    end
  end

  describe '#relative_path' do
    subject { object.__send__(:relative_path, source_path) }

    let(:source_path) { Pathname.new('/app/app/models/user.rb') }

    it 'returns a string path relative to the configured root' do
      expect(subject).to eql('app/models/user.rb')
      expect(subject).to be_instance_of(String)
    end

    context 'when the path is outside the configured root' do
      let(:source_path) { Pathname.new('/tmp/app/models/user.rb') }

      it 'returns the relative traversal path string' do
        expect(subject).to eql('../tmp/app/models/user.rb')
      end
    end

    context 'when pathname coercion raises ArgumentError' do
      let(:source_path) { instance_double(Pathname, to_s: '/tmp/coercion-failed.rb') }

      before do
        allow(Pathname).to receive(:new).and_call_original
        expect(Pathname).to receive(:new).with(source_path).and_raise(ArgumentError)
      end

      it 'returns the original path string' do
        expect(subject).to eql('/tmp/coercion-failed.rb')
      end
    end

    context 'when relative_path_from raises ArgumentError' do
      let(:root)        { Pathname.new('app') }
      let(:source_path) { Pathname.new('/tmp/app/models/user.rb') }

      it 'falls back to the original absolute path string' do
        expect(subject).to eql('/tmp/app/models/user.rb')
      end
    end

    context 'when the source path is not a pathname instance' do
      let(:source_path) { '/app/app/models/user.rb' }

      it 'normalizes the source path through the configured pathname class' do
        expect(subject).to eql('app/models/user.rb')
      end
    end
  end
end

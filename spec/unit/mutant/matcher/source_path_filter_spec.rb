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
  end
end

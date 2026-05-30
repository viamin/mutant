# frozen_string_literal: true

RSpec.describe Mutant::Matcher::SourcePath, '#call' do
  subject { object.call(bootstrap_env).map { |s| s.expression.syntax }.sort }

  let(:object)        { described_class.new('lib/test_app/subjects.rb') }
  let(:bootstrap_env) { Mutant::Env::Bootstrap.new(Fixtures::TEST_CONFIG) }

  around do |example|
    Dir.chdir(TestApp.root, &example)
  end

  it 'returns subjects defined in matching files' do
    expect(subject).to eql(
      %w[
        TestApp::SubjectMatchers::Nested::Child#gamma
        TestApp::SubjectMatchers::Prepended#prepended_instance
        TestApp::SubjectMatchers::Root#alpha
        TestApp::SubjectMatchers::Root.beta
      ]
    )
  end
end

RSpec.describe Mutant::Matcher::SourcePath, '.match?' do
  subject { described_class.match?(glob, source_path) }

  context 'when absolute path matches glob directly' do
    let(:glob)        { '/workspace/**/*.rb' }
    let(:source_path) { Pathname.new('/workspace/lib/foo.rb') }

    it { should be(true) }
  end

  context 'when path does not match glob' do
    let(:glob)        { 'lib/**/*.rb' }
    let(:source_path) { 'spec/foo_spec.rb' }

    it { should be(false) }
  end

  context 'when source_path is a Pathname' do
    let(:glob)        { 'lib/**/*.rb' }
    let(:source_path) { Pathname.new('lib/foo.rb') }

    it { should be(true) }
  end

  context 'when path matches only via relative conversion' do
    let(:glob)        { 'lib/**/*.rb' }
    let(:source_path) { File.join(Dir.pwd, 'lib/foo.rb') }

    it { should be(true) }
  end

  context 'when source_path is a non-string, non-pathname object' do
    let(:glob) { 'lib/**/*.rb' }

    let(:source_path) do
      object = Object.new
      allow(object).to receive(:to_s).and_return('lib/foo.rb')
      object
    end

    it { should be(true) }
  end

  context 'when path matches via extglob pattern' do
    let(:glob)        { File.join(Dir.pwd, '**/*.{rb}') }
    let(:source_path) { File.join(Dir.pwd, 'lib', 'foo.rb') }

    it { should be(true) }
  end
end

RSpec.describe Mutant::Matcher::SourcePath, '.relative_path' do
  subject { described_class.send(:relative_path, path) }

  context 'when path is relative to pwd' do
    let(:path) { File.join(Dir.pwd, 'lib', 'foo.rb') }

    it 'returns a relative path string' do
      expect(subject).to eql('lib/foo.rb')
      expect(subject).to be_a(String)
    end
  end

  context 'when path cannot be made relative' do
    let(:path) { 'relative/path/file.rb' }

    it 'returns the original path' do
      expect(subject).to eql(path)
    end
  end
end

RSpec.describe Mutant::Matcher::SourcePath, '#candidate_method_names' do
  let(:object) { described_class.new('**/*.rb') }

  subject { object.send(:candidate_method_names, scope, names) }

  let(:names) { %i[public_instance_methods private_instance_methods] }
  let(:scope) do
    Class.new do
      def self.public_instance_methods
        %i[zebra]
      end

      def self.private_instance_methods
        %i[alpha]
      end
    end
  end

  it 'returns sorted method names' do
    expect(subject).to eql(%i[alpha zebra])
  end
end

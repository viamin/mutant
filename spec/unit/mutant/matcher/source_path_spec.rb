# frozen_string_literal: true

RSpec.describe Mutant::Matcher::SourcePath, '#call' do
  subject { object.call(bootstrap_env).map { |subject| subject.expression.syntax }.sort }

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

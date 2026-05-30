# frozen_string_literal: true

RSpec.describe Mutant::Results::Document do
  let(:repo_root) { Pathname.new(@directory) }

  around do |example|
    Dir.mktmpdir do |directory|
      @directory = directory
      example.run
    end
  end

  let(:status) { instance_double(Process::Status, success?: true) }
  let(:open3)  { class_double(Open3)                              }
  let(:sha)    { 'abcdef1234567890abcdef1234567890abcdef12'       }

  let(:config) do
    Mutant::Config::DEFAULT.with(
      open3:       open3,
      results_dir: File.join(@directory, 'results')
    )
  end

  let(:env)    { instance_double(Mutant::Env, config: config) }
  let(:result) do
    instance_double(
      Mutant::Result::Env,
      amount_mutations: 1,
      env:              env,
      subject_results:  [subject_result]
    )
  end
  let(:object) { described_class.new(result, sha, '2026-05-29T14:00:00Z') }

  let(:subject_expression) { instance_double(Mutant::Expression, syntax: 'TestApp::Foo#bar') }
  let(:subject_path)       { repo_root.join('lib/../lib/test_app/foo.rb') }
  let(:subject) do
    instance_double(
      Mutant::Subject,
      expression:  subject_expression,
      source_line: 17,
      source_path: subject_path
    )
  end
  let(:mutation) do
    instance_double(
      Mutant::Mutation,
      subject:         subject,
      original_source: "return true\n",
      source:          "return false\n"
    )
  end
  let(:isolation_result) { Mutant::Isolation::Result::Exception.new(RuntimeError.new('boom')) }
  let(:mutation_result) do
    instance_double(
      Mutant::Result::Mutation,
      mutation:         mutation,
      isolation_result: isolation_result,
      success?:         false
    )
  end
  let(:subject_result) do
    instance_double(Mutant::Result::Subject, mutation_results: [mutation_result])
  end

  before do
    allow(open3).to receive(:capture2)
      .with('git', 'rev-parse', '--show-toplevel', binmode: true)
      .and_return([repo_root.to_s + "\n", status])
  end

  describe '.call' do
    it 'serializes the full result payload' do
      expect(object.to_h).to eql(
        'ran_at'            => '2026-05-29T14:00:00Z',
        'git_ref'           => sha,
        'since'             => nil,
        'total_mutations'   => 1,
        'killed'            => 0,
        'alive'             => 0,
        'errored'           => 1,
        'alive_mutations'   => [],
        'errored_mutations' => [
          {
            'subject' => 'TestApp::Foo#bar',
            'error'   => 'RuntimeError: boom'
          }
        ]
      )
    end

    it 'normalizes absolute paths relative to the repository root' do
      expect(object.send(:subject_path, subject)).to eql('lib/test_app/foo.rb')
    end

    it 'keeps relative paths and cleans them up' do
      relative_subject = instance_double(Mutant::Subject, source_path: Pathname.new('lib/../lib/test_app/foo.rb'))

      expect(object.send(:subject_path, relative_subject)).to eql('lib/test_app/foo.rb')
    end

    context 'when git rev-parse --show-toplevel fails' do
      let(:status) { instance_double(Process::Status, success?: false) }

      it 'raises a repository error with the expected class and message' do
        error = nil

        begin
          object.send(:repo_root)
        rescue StandardError => exception
          error = exception
        end

        aggregate_failures do
          expect(error.class).to be(Mutant::Repository::RepositoryError)
          expect(error.message).to eql('Command ["git", "rev-parse", "--show-toplevel"] failed!')
        end
      end
    end
  end

  describe Mutant::Results::Document::ErrorMessage do
    let(:object) { described_class }

    it 'formats error chains by using the first nested error' do
      error_chain = Mutant::Isolation::Result::ErrorChain.new(
        Mutant::Isolation::Result::Exception.new(RuntimeError.new('boom')),
        Mutant::Isolation::Result::Exception.new(ArgumentError.new('ignored'))
      )

      expect(object.call(error_chain)).to eql('RuntimeError: boom')
    end

    it 'formats non-exception error payloads via inspect' do
      expect(object.call(Mutant::Isolation::Result::Exception.new(:boom))).to eql(':boom')
    end
  end

  describe Mutant::Results::Document::MutationDiff do
    let(:object) { described_class }

    it 'returns an empty string when the sources are identical' do
      mutation = instance_double(Mutant::Mutation, original_source: "same\n", source: "same\n")

      expect(object.call(mutation)).to eql('')
    end

    it 'filters diff headers and keeps only changed lines' do
      mutation = instance_double(Mutant::Mutation, original_source: "- 1\n", source: "+ 2\n")

      expect(object.call(mutation)).to eql("-- 1\n++ 2\n")
    end
  end
end

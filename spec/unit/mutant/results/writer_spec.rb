# frozen_string_literal: true

RSpec.describe Mutant::Results::Writer do
  let(:object) { described_class }
  let(:repo_root) { Pathname.new(@directory) }

  around do |example|
    Dir.mktmpdir do |directory|
      @directory = directory
      example.run
    end
  end

  let(:status) { instance_double(Process::Status, success?: true) }
  let(:open3)  { class_double(Open3)                              }
  let(:time)   { Time.utc(2026, 5, 29, 14, 0, 0)                  }
  let(:sha)    { 'abcdef1234567890abcdef1234567890abcdef12'       }
  let(:since)  { nil                                              }
  let(:run_id) { 'deadbeefcafe'                                   }

  let(:config) do
    Mutant::Config::DEFAULT.with(
      open3:       open3,
      results_dir: results_dir,
      since:       since
    )
  end

  let(:results_dir) { File.join(@directory, 'results') }
  let(:env)         { instance_double(Mutant::Env, config: config) }

  before do
    allow(Time).to receive(:now).and_return(time)
    allow(SecureRandom).to receive(:hex).with(6).and_return(run_id)
    allow(open3).to receive(:capture2)
      .with('git', 'rev-parse', 'HEAD', binmode: true)
      .and_return([sha + "\n", status])
    allow(open3).to receive(:capture2)
      .with('git', 'rev-parse', '--show-toplevel', binmode: true)
      .and_return([repo_root.to_s + "\n", status])
  end

  describe '.call' do
    subject(:path) { object.call(result) }

    let(:result) do
      instance_double(
        Mutant::Result::Env,
        amount_mutations: 3,
        env:              env,
        subject_results:  [subject_result]
      )
    end

    let(:alive_subject_expression) { instance_double(Mutant::Expression, syntax: 'TestApp::Foo#bar') }
    let(:alive_subject) do
      instance_double(
        Mutant::Subject,
        expression:  alive_subject_expression,
        source_line: 17,
        source_path: repo_root.join('lib/test_app/foo.rb')
      )
    end
    let(:alive_mutation) do
      instance_double(
        Mutant::Mutation,
        subject:         alive_subject,
        original_source: "return true\n",
        source:          "return false\n"
      )
    end
    let(:alive_isolation_result) { instance_double(Mutant::Isolation::Result, success?: true) }
    let(:alive_result) do
      instance_double(
        Mutant::Result::Mutation,
        isolation_result: alive_isolation_result,
        mutation:         alive_mutation,
        success?:         false
      )
    end

    let(:killed_isolation_result) { instance_double(Mutant::Isolation::Result, success?: true) }
    let(:killed_result) do
      instance_double(
        Mutant::Result::Mutation,
        isolation_result: killed_isolation_result,
        mutation:         instance_double(Mutant::Mutation),
        success?:         true
      )
    end

    let(:errored_subject_expression) { instance_double(Mutant::Expression, syntax: 'TestApp::Bar#baz') }
    let(:errored_subject)            { instance_double(Mutant::Subject, expression: errored_subject_expression) }
    let(:errored_mutation)           { instance_double(Mutant::Mutation, subject: errored_subject) }
    let(:errored_isolation_result) do
      Mutant::Isolation::Result::Exception.new(RuntimeError.new('boom'))
    end
    let(:errored_result) do
      instance_double(
        Mutant::Result::Mutation,
        isolation_result: errored_isolation_result,
        mutation:         errored_mutation,
        success?:         false
      )
    end

    let(:subject_result) do
      instance_double(
        Mutant::Result::Subject,
        mutation_results: [alive_result, killed_result, errored_result]
      )
    end

    it 'writes round-trippable machine readable results' do
      expect(path.basename.to_s).to eql('20260529T140000Z-abcdef1-deadbeefcafe.yml')
      expect(
        YAML.safe_load_file(path, permitted_classes: [Symbol, Time])
      ).to eql(
        'ran_at'            => '2026-05-29T14:00:00Z',
        'git_ref'           => sha,
        'since'             => nil,
        'total_mutations'   => 3,
        'killed'            => 1,
        'alive'             => 1,
        'errored'           => 1,
        'alive_mutations'   => [
          {
            'subject'       => 'TestApp::Foo#bar',
            'subject_path'  => 'lib/test_app/foo.rb',
            'source_line'   => 17,
            'mutation_diff' => "-return true\n+return false\n"
          }
        ],
        'errored_mutations' => [
          {
            'subject' => 'TestApp::Bar#baz',
            'error'   => 'RuntimeError: boom'
          }
        ]
      )
    end

    it 'writes one file per invocation' do
      allow(SecureRandom).to receive(:hex).with(6).and_return('deadbeefcafe', 'cafebabefeed')

      first_path  = object.call(result)
      second_path = object.call(result)

      aggregate_failures do
        expect(first_path.basename.to_s).to eql('20260529T140000Z-abcdef1-deadbeefcafe.yml')
        expect(second_path.basename.to_s).to eql('20260529T140000Z-abcdef1-cafebabefeed.yml')
        expect(first_path.read).not_to eql('')
        expect(second_path.read).to eql(first_path.read)
      end
    end

    it 'uses one instant for the filename and document timestamp' do
      allow(Time).to receive(:now).and_return(time, time + 1)

      expect(path.basename.to_s).to eql('20260529T140000Z-abcdef1-deadbeefcafe.yml')
      expect(
        YAML.safe_load_file(path, permitted_classes: [Symbol, Time]).fetch('ran_at')
      ).to eql('2026-05-29T14:00:00Z')
    end

    it 'normalizes the timestamp to utc for both filename and document timestamp' do
      allow(Time).to receive(:now).and_return(Time.new(2026, 5, 29, 7, 0, 0, '-07:00'))

      expect(path.basename.to_s).to eql('20260529T140000Z-abcdef1-deadbeefcafe.yml')
      expect(
        YAML.safe_load_file(path, permitted_classes: [Symbol, Time]).fetch('ran_at')
      ).to eql('2026-05-29T14:00:00Z')
    end

    context 'when mutation source content starts with - or +' do
      let(:alive_mutation) do
        instance_double(
          Mutant::Mutation,
          subject:         alive_subject,
          original_source: "- 1\n",
          source:          "+ 2\n"
        )
      end

      it 'includes diff lines whose content begins with - or +' do
        data = YAML.safe_load_file(path, permitted_classes: [Symbol, Time])
        diff = data['alive_mutations'].first['mutation_diff']
        expect(diff).to eql("-- 1\n++ 2\n")
      end
    end

    context 'when mutation isolation errors are chained' do
      let(:errored_isolation_result) do
        Mutant::Isolation::Result::ErrorChain.new(
          Mutant::Isolation::Result::Exception.new(RuntimeError.new('boom')),
          Mutant::Isolation::Result::Exception.new(ArgumentError.new('ignored'))
        )
      end

      it 'reports the first nested exception message' do
        data = YAML.safe_load_file(path, permitted_classes: [Symbol, Time])

        expect(data.fetch('errored_mutations')).to include(
          'subject' => 'TestApp::Bar#baz',
          'error'   => 'RuntimeError: boom'
        )
      end
    end

    context 'when git rev-parse HEAD fails' do
      let(:status) { instance_double(Process::Status, success?: false) }

      it 'raises a repository error' do
        expect { path }.to raise_error(
          Mutant::Repository::RepositoryError,
          'Command ["git", "rev-parse", "HEAD"] failed!'
        )
      end
    end

    context 'when the run is a no-op since selection' do
      let(:since) { 'main' }
      let(:result) do
        instance_double(
          Mutant::Result::Env,
          amount_mutations: 0,
          env:              env,
          subject_results:  []
        )
      end

      it 'still writes an empty result file' do
        expect(
          YAML.safe_load_file(path, permitted_classes: [Symbol, Time])
        ).to eql(
          'ran_at'            => '2026-05-29T14:00:00Z',
          'git_ref'           => sha,
          'since'             => 'main',
          'total_mutations'   => 0,
          'killed'            => 0,
          'alive'             => 0,
          'errored'           => 0,
          'alive_mutations'   => [],
          'errored_mutations' => []
        )
      end
    end
  end
end

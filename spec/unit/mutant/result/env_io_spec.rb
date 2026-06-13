# frozen_string_literal: true

RSpec.describe Mutant::Result::Env::IO do
  let(:object) { described_class.new(env_result) }

  let(:env_result) do
    instance_double(
      Mutant::Result::Env,
      env:             env,
      subject_results: [subject_result]
    )
  end

  let(:env) do
    instance_double(
      Mutant::Env,
      config:    config,
      mutations: [],
      subjects:  [subject_a]
    )
  end

  let(:config) do
    instance_double(
      Mutant::Config,
      open3:          Open3,
      pathname:       Pathname,
      results_dir:    results_dir,
      reporter:       instance_double(Mutant::Reporter),
      since_revision: since_revision
    )
  end

  let(:results_dir) { Pathname.new Dir.mktmpdir }
  let(:since_revision) { 'main' }

  let(:subject_a) do
    instance_double(
      Mutant::Subject,
      identification: 'TestApp::Foo#bar',
      source_path:    Pathname.new('app/models/foo.rb'),
      source_line:    17,
      source:         "return true\n"
    )
  end

  let(:mutation_alive) do
    instance_double(
      Mutant::Mutation,
      subject: subject_a,
      source:  "return false\n"
    )
  end

  let(:mutation_killed) do
    instance_double(
      Mutant::Mutation,
      subject: subject_a,
      source:  "return nil\n"
    )
  end

  let(:mutation_killed_b) do
    instance_double(
      Mutant::Mutation,
      subject: subject_a,
      source:  "return 0\n"
    )
  end

  let(:mutation_errored) do
    instance_double(
      Mutant::Mutation,
      subject: subject_a,
      source:  "raise\n"
    )
  end

  let(:alive_isolation_result) do
    instance_double(Mutant::Isolation::Result::Success, success?: true)
  end

  let(:killed_isolation_result) do
    instance_double(Mutant::Isolation::Result::Success, success?: true)
  end

  let(:error_isolation_result) do
    instance_double(
      Mutant::Isolation::Result::Exception,
      success?: false,
      value:    exception
    )
  end

  let(:exception) { RuntimeError.new('TimeoutError: 30s elapsed') }

  let(:mutation_alive_result) do
    instance_double(
      Mutant::Result::Mutation,
      mutation:         mutation_alive,
      isolation_result: alive_isolation_result,
      success?:         false,
      runtime:          1.0
    )
  end

  let(:mutation_killed_result) do
    instance_double(
      Mutant::Result::Mutation,
      mutation:         mutation_killed,
      isolation_result: killed_isolation_result,
      success?:         true,
      runtime:          1.0
    )
  end

  let(:mutation_killed_b_result) do
    instance_double(
      Mutant::Result::Mutation,
      mutation:         mutation_killed_b,
      isolation_result: killed_isolation_result,
      success?:         true,
      runtime:          1.0
    )
  end

  let(:mutation_errored_result) do
    instance_double(
      Mutant::Result::Mutation,
      mutation:         mutation_errored,
      isolation_result: error_isolation_result,
      success?:         false,
      runtime:          1.0
    )
  end

  let(:subject_result) do
    instance_double(
      Mutant::Result::Subject,
      subject:          subject_a,
      mutation_results: [
        mutation_alive_result,
        mutation_killed_result,
        mutation_killed_b_result,
        mutation_errored_result
      ]
    )
  end

  describe '#call' do
    subject { object.call }

    it 'writes a YAML file to the results directory' do
      subject
      files = Dir.glob(results_dir.join('*.yml'))
      expect(files.length).to eql(1)
    end

    it 'filename follows timestamp-sha pattern' do
      subject
      files = Dir.glob(results_dir.join('*.yml'))
      expect(File.basename(files.first)).to match(/\A\d{8}T\d{6}Z-[0-9a-f]{7}\.yml\z/)
    end

    it 'uses the first 7 characters of the git ref in the filename' do
      subject
      files = Dir.glob(results_dir.join('*.yml'))
      expected_ref = `git rev-parse HEAD`.strip
      filename = File.basename(files.first, '.yml')
      ref_part = filename.split('-', 2).last
      expect(ref_part).to eql(expected_ref[0, 7])
    end

    it 'creates the results directory if missing' do
      missing_dir = results_dir.join('nested', 'dir')
      allow(config).to receive(:results_dir).and_return(missing_dir)

      expect { described_class.new(env_result).call }
        .to change { missing_dir.exist? }.from(false).to(true)
    end

    describe 'YAML content' do
      let(:yaml_content) do
        subject
        files = Dir.glob(results_dir.join('*.yml'))
        YAML.safe_load_file(files.first, permitted_classes: [Symbol, Time])
      end

      it 'contains ran_at as a Time' do
        expect(yaml_content['ran_at']).to be_a(Time)
      end

      it 'ran_at is in UTC' do
        expect(yaml_content['ran_at'].utc?).to be(true)
      end

      it 'contains git_ref as a string' do
        expect(yaml_content['git_ref']).to be_a(String)
      end

      it 'contains since revision' do
        expect(yaml_content['since']).to eql('main')
      end

      it 'contains total_mutations count' do
        expect(yaml_content['total_mutations']).to eql(4)
      end

      it 'contains killed count' do
        expect(yaml_content['killed']).to eql(2)
      end

      it 'contains alive count' do
        expect(yaml_content['alive']).to eql(1)
      end

      it 'contains errored count' do
        expect(yaml_content['errored']).to eql(1)
      end

      it 'contains alive_mutations array' do
        expect(yaml_content['alive_mutations'].length).to eql(1)
      end

      it 'alive mutation has subject' do
        expect(yaml_content['alive_mutations'].first['subject']).to eql('TestApp::Foo#bar')
      end

      it 'alive mutation has subject_path' do
        expect(yaml_content['alive_mutations'].first['subject_path']).to eql('app/models/foo.rb')
      end

      it 'alive mutation has source_line' do
        expect(yaml_content['alive_mutations'].first['source_line']).to eql(17)
      end

      it 'alive mutation has mutation_diff' do
        expect(yaml_content['alive_mutations'].first['mutation_diff']).to include('-')
      end

      it 'contains errored_mutations array' do
        expect(yaml_content['errored_mutations'].length).to eql(1)
      end

      it 'errored mutation has subject' do
        expect(yaml_content['errored_mutations'].first['subject']).to eql('TestApp::Foo#bar')
      end

      it 'errored mutation has error' do
        expect(yaml_content['errored_mutations'].first['error']).to eql(exception.inspect)
      end

      it 'is round-trippable via YAML.safe_load_file' do
        subject
        files = Dir.glob(results_dir.join('*.yml'))
        loaded = YAML.safe_load_file(files.first, permitted_classes: [Symbol, Time])

        expect(loaded['total_mutations']).to eql(4)
        expect(loaded['killed']).to eql(2)
        expect(loaded['alive']).to eql(1)
        expect(loaded['errored']).to eql(1)
        expect(loaded['alive_mutations']).to be_a(Array)
        expect(loaded['errored_mutations']).to be_a(Array)
      end

      it 'uses string keys not symbol keys' do
        subject
        files = Dir.glob(results_dir.join('*.yml'))
        loaded = YAML.safe_load_file(files.first, permitted_classes: [Symbol, Time])

        expect(loaded.keys).to all(be_a(String))
      end
    end

    context 'when since_revision is nil' do
      let(:since_revision) { nil }

      it 'writes null for since' do
        subject
        files = Dir.glob(results_dir.join('*.yml'))
        loaded = YAML.safe_load_file(files.first, permitted_classes: [Symbol, Time])
        expect(loaded['since']).to be_nil
      end
    end

    context 'when errored mutation has ForkError isolation result' do
      let(:fork_error_isolation_result) do
        Mutant::Isolation::Fork::ForkError.new
      end

      let(:mutation_fork_error_result) do
        instance_double(
          Mutant::Result::Mutation,
          mutation:         mutation_errored,
          isolation_result: fork_error_isolation_result,
          success?:         false,
          runtime:          1.0
        )
      end

      let(:subject_result) do
        instance_double(
          Mutant::Result::Subject,
          subject:          subject_a,
          mutation_results: [mutation_fork_error_result]
        )
      end

      it 'uses the isolation result class name as error' do
        subject
        files = Dir.glob(results_dir.join('*.yml'))
        loaded = YAML.safe_load_file(files.first, permitted_classes: [Symbol, Time])
        expect(loaded['errored_mutations'].first['error']).to eql('Mutant::Isolation::Fork::ForkError')
      end

      it 'counts errored correctly' do
        subject
        files = Dir.glob(results_dir.join('*.yml'))
        loaded = YAML.safe_load_file(files.first, permitted_classes: [Symbol, Time])
        expect(loaded['errored']).to eql(1)
        expect(loaded['total_mutations']).to eql(1)
      end
    end

    context 'when errored mutation has a ForkError subclass' do
      let(:fork_error_subclass) do
        Class.new(Mutant::Isolation::Fork::ForkError).new
      end

      let(:mutation_fork_subclass_result) do
        instance_double(
          Mutant::Result::Mutation,
          mutation:         mutation_errored,
          isolation_result: fork_error_subclass,
          success?:         false,
          runtime:          1.0
        )
      end

      let(:subject_result) do
        instance_double(
          Mutant::Result::Subject,
          subject:          subject_a,
          mutation_results: [mutation_fork_subclass_result]
        )
      end

      it 'uses the subclass class name as error' do
        subject
        files = Dir.glob(results_dir.join('*.yml'))
        loaded = YAML.safe_load_file(files.first, permitted_classes: [Symbol, Time])
        expect(loaded['errored_mutations'].first['error']).to eql(fork_error_subclass.class.name)
      end
    end

    context 'when errored mutation has SerializedException' do
      let(:serialized_exception) do
        Mutant::Isolation::Result::SerializedException.new(
          [],
          'TimeoutError',
          '#<TimeoutError: 30s elapsed>'
        )
      end

      let(:error_isolation_result) do
        instance_double(
          Mutant::Isolation::Result::Exception,
          success?: false,
          value:    serialized_exception
        )
      end

      it 'formats the error with class name' do
        subject
        files = Dir.glob(results_dir.join('*.yml'))
        loaded = YAML.safe_load_file(files.first, permitted_classes: [Symbol, Time])
        expect(loaded['errored_mutations'].first['error']).to eql('TimeoutError: #<TimeoutError: 30s elapsed>')
      end
    end

    context 'when git command fails' do
      let(:fake_open3) { class_double(Open3) }
      let(:failed_status) { instance_double(Process::Status, success?: false) }

      before do
        allow(config).to receive(:open3).and_return(fake_open3)
        allow(fake_open3).to receive(:capture2)
          .with('git', 'rev-parse', 'HEAD', binmode: true)
          .and_return(['', failed_status])
      end

      it 'uses "unknown" as git_ref' do
        subject
        files = Dir.glob(results_dir.join('*.yml'))
        loaded = YAML.safe_load_file(files.first, permitted_classes: [Symbol, Time])
        expect(loaded['git_ref']).to eql('unknown')
      end

      it 'uses "unknown" prefix in filename' do
        subject
        files = Dir.glob(results_dir.join('*.yml'))
        expect(File.basename(files.first)).to match(/\A\d{8}T\d{6}Z-unknown\.yml\z/)
      end
    end

    context 'when git command returns ref with trailing whitespace' do
      let(:fake_open3) { class_double(Open3) }
      let(:success_status) { instance_double(Process::Status, success?: true) }

      before do
        allow(config).to receive(:open3).and_return(fake_open3)
        allow(fake_open3).to receive(:capture2)
          .with('git', 'rev-parse', 'HEAD', binmode: true)
          .and_return(["abc123def456\n", success_status])
      end

      it 'strips whitespace from git_ref' do
        subject
        files = Dir.glob(results_dir.join('*.yml'))
        loaded = YAML.safe_load_file(files.first, permitted_classes: [Symbol, Time])
        expect(loaded['git_ref']).to eql('abc123def456')
      end
    end

    context 'when alive mutation source matches subject source' do
      let(:mutation_alive_same) do
        instance_double(
          Mutant::Mutation,
          subject: subject_a,
          source:  "return true\n"
        )
      end

      let(:mutation_alive_same_result) do
        instance_double(
          Mutant::Result::Mutation,
          mutation:         mutation_alive_same,
          isolation_result: alive_isolation_result,
          success?:         false,
          runtime:          1.0
        )
      end

      let(:subject_result) do
        instance_double(
          Mutant::Result::Subject,
          subject:          subject_a,
          mutation_results: [mutation_alive_same_result]
        )
      end

      it 'mutation_diff falls back to empty string' do
        subject
        files = Dir.glob(results_dir.join('*.yml'))
        loaded = YAML.safe_load_file(files.first, permitted_classes: [Symbol, Time])
        expect(loaded['alive_mutations'].first['mutation_diff']).to eql('')
      end
    end
  end

  describe 'schema round-trip' do
    subject { object.call }

    it 'preserves all scalar types through YAML serialization' do
      subject
      files = Dir.glob(results_dir.join('*.yml'))
      loaded = YAML.safe_load_file(files.first, permitted_classes: [Symbol, Time])

      expect(loaded['ran_at']).to be_a(Time)
      expect(loaded['git_ref']).to be_a(String)
      expect(loaded['total_mutations']).to be_a(Integer)
      expect(loaded['killed']).to be_a(Integer)
      expect(loaded['alive']).to be_a(Integer)
      expect(loaded['errored']).to be_a(Integer)
      expect(loaded['alive_mutations']).to be_a(Array)
      expect(loaded['errored_mutations']).to be_a(Array)
    end
  end
end

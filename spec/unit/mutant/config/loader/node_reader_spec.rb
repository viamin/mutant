# frozen_string_literal: true

RSpec.describe Mutant::Config::Loader::NodeReader do
  let(:object) { described_class.new(path) }
  let(:path)   { Pathname.new('/tmp/.mutant.yml') }

  def document_root(source)
    Psych.parse(source).root
  end

  describe '#mapping' do
    subject { object.mapping(node, context, allowed_keys) }

    let(:context)      { ['matcher'] }
    let(:allowed_keys) { %w[subjects ignore] }

    context 'with a valid mapping' do
      let(:node) do
        document_root(<<~YAML)
          subjects:
            - TestApp*
          ignore:
            - app/admin/**/*.rb
        YAML
      end

      it 'returns key node pairs' do
        expect(subject).to all(have_attributes(size: 2))
        expect(subject.map(&:first)).to eql(%w[subjects ignore])
        expect(subject.map(&:last)).to all(be_instance_of(Psych::Nodes::Sequence))
      end
    end

    context 'with a non-string key' do
      let(:node) do
        document_root(<<~YAML)
          false:
            - TestApp*
        YAML
      end

      it 'raises a validation error using the mapping context' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          'Invalid value for matcher at /tmp/.mutant.yml:1: expected "String"'
        )
      end
    end

    context 'with an unknown key' do
      let(:node) do
        document_root(<<~YAML)
          subjects:
            - TestApp*
          invalid: true
        YAML
      end

      it 'raises a line-aware error' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          'Unknown config key "matcher.invalid" at /tmp/.mutant.yml:3'
        )
      end
    end

    context 'with an unknown key in nested context' do
      let(:context) { %w[config matcher] }
      let(:node) do
        document_root(<<~YAML)
          invalid: true
        YAML
      end

      it 'raises a line-aware error with the full nested path' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          'Unknown config key "config.matcher.invalid" at /tmp/.mutant.yml:1'
        )
      end
    end

    context 'with an invalid node type' do
      let(:node) { document_root("- TestApp*\n") }

      it 'raises a validation error' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          'Invalid value for matcher at /tmp/.mutant.yml:1: expected mapping'
        )
      end
    end

    context 'with an invalid node type for nested context' do
      let(:context) { %w[config matcher] }
      let(:node)    { document_root("- TestApp*\n") }

      it 'raises a validation error with the full nested path' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          'Invalid value for config.matcher at /tmp/.mutant.yml:1: expected mapping'
        )
      end
    end
  end

  describe '#string_list' do
    subject { object.string_list(node, context) }

    let(:context) { ['requires'] }

    context 'with a valid sequence' do
      let(:node) { document_root("- ./config/environment\n- ./config/boot\n") }

      it { should eql(['./config/environment', './config/boot']) }
    end

    context 'with a scalar node' do
      let(:node) { document_root("requires\n") }

      it 'raises a validation error' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          'Invalid value for requires at /tmp/.mutant.yml:1: expected sequence'
        )
      end
    end

    context 'with a non-string child value' do
      let(:node) { document_root("- false\n") }

      it 'raises a validation error using the list context' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          'Invalid value for requires at /tmp/.mutant.yml:1: expected "String"'
        )
      end
    end
  end

  describe '#string_hash' do
    subject { object.string_hash(node, context) }

    let(:context) { ['environment_variables'] }

    context 'with a valid mapping' do
      let(:node) do
        document_root(<<~YAML)
          RAILS_ENV: test
          COVERAGE: "false"
        YAML
      end

      it { should eql('RAILS_ENV' => 'test', 'COVERAGE' => 'false') }
    end

    context 'with a non-string value' do
      let(:node) { document_root("RAILS_ENV: false\n") }

      it 'raises a validation error' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          'Invalid value for environment_variables.RAILS_ENV at /tmp/.mutant.yml:1: expected "String"'
        )
      end
    end

    context 'with an invalid node type' do
      let(:node) { document_root("- RAILS_ENV\n") }

      it 'raises a validation error' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          'Invalid value for environment_variables at /tmp/.mutant.yml:1: expected mapping'
        )
      end
    end

    context 'with a non-string key' do
      let(:node) { document_root("false: test\n") }

      it 'raises a validation error using the mapping context' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          'Invalid value for environment_variables at /tmp/.mutant.yml:1: expected "String"'
        )
      end
    end
  end

  describe '#integer' do
    subject { object.integer(node, ['jobs']) }

    let(:node) { document_root("1\n") }

    it { should eql(1) }

    context 'when the value is not an integer' do
      let(:node) { document_root("1.0\n") }

      it 'raises a validation error' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          'Invalid value for jobs at /tmp/.mutant.yml:1: expected "Integer"'
        )
      end
    end

    context 'when the value is not an integer for nested context' do
      subject { object.integer(node, %w[coverage_criteria timeout]) }

      let(:node) { document_root("1.0\n") }

      it 'raises a validation error with the full nested path' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          'Invalid value for coverage_criteria.timeout at /tmp/.mutant.yml:1: expected "Integer"'
        )
      end
    end
  end

  describe '#boolean' do
    subject { object.boolean(node, ['fail_fast']) }

    context 'when the value is true' do
      let(:node) { document_root("true\n") }

      it { should be(true) }
    end

    context 'when the value is false' do
      let(:node) { document_root("false\n") }

      it { should be(false) }
    end

    context 'when the value is not a boolean' do
      let(:node) { document_root("nil\n") }

      it 'raises a validation error' do
        expect { subject }.to raise_error(
          Mutant::Config::Loader::Error,
          'Invalid value for fail_fast at /tmp/.mutant.yml:1: expected "Boolean"'
        )
      end
    end
  end
end

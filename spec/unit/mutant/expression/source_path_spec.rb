# frozen_string_literal: true

RSpec.describe Mutant::Expression::SourcePath do
  let(:object) { parse_expression(input) }
  let(:input)  { 'source:app/models/**/*.rb' }

  describe '#matcher' do
    subject { object.matcher }

    it { should eql(Mutant::Matcher::SourcePath.new('app/models/**/*.rb')) }
  end

  describe '#syntax' do
    subject { object.syntax }

    it { should eql(input) }
  end

  describe '#subject_predicate' do
    subject { object.subject_predicate }

    it { should eql(Mutant::Expression::SourcePath::Predicate.new('app/models/**/*.rb')) }
  end

  describe Mutant::Expression::SourcePath::Predicate, '#call' do
    let(:predicate) { described_class.new(glob) }

    context 'when subject source path matches the glob' do
      let(:glob) { 'lib/**/*.rb' }

      let(:subject_instance) do
        instance_double(Mutant::Subject, source_path: 'lib/foo.rb')
      end

      it 'returns true' do
        expect(predicate.call(subject_instance)).to be(true)
      end
    end

    context 'when subject source path does not match the glob' do
      let(:glob) { 'lib/**/*.rb' }

      let(:subject_instance) do
        instance_double(Mutant::Subject, source_path: 'spec/foo_spec.rb')
      end

      it 'returns false' do
        expect(predicate.call(subject_instance)).to be(false)
      end
    end
  end
end

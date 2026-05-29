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
end

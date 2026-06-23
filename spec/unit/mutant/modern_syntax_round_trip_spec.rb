# frozen_string_literal: true

RSpec.describe 'modern syntax mutation round-trip' do
  let(:fixture_path) { Pathname.new(__dir__).join('../../fixtures/modern_syntax.rb').expand_path }
  let(:root)         { Unparser.parse(fixture_path.read) }

  it 'unparses and reparses rooted mutations from the existing operator set' do
    Mutant::Mutator.mutate(root).each do |mutation|
      source = Unparser.unparse(mutation)
      expect { Unparser.parse(source) }.not_to raise_error
    end
  end
end

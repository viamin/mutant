# frozen_string_literal: true

require 'test_app/prepended_method'

RSpec.describe 'prepended class method matching' do
  let(:env)     { Fixtures::TEST_ENV }
  let(:matcher) { parse_expression('ExactMatcherFixtures::Target#execute').matcher }

  around do |example|
    Dir.chdir(TestApp.root, &example)
  end

  it 'matches the class body and preserves dispatch through every wrapper when inserting mutations' do
    subject = matcher.call(env).fetch(0)

    expect(subject.expression.syntax).to eql('ExactMatcherFixtures::Target#execute')

    subject.mutations.first.insert(Kernel)
    expect(ExactMatcherFixtures::Target.new.execute).to eql([:outer, [:inner, :body]])

    Mutant::Mutation::Evil.new(
      subject,
      s(:def, :execute, s(:args), s(:sym, :changed))
    ).insert(Kernel)

    expect(ExactMatcherFixtures::Target.new.execute).to eql([:outer, [:inner, :changed]])
  end
end

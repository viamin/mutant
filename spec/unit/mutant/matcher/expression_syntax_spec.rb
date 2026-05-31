# frozen_string_literal: true

RSpec.describe 'subject matcher expression syntax' do
  let(:bootstrap_env) { Mutant::Env::Bootstrap.new(Fixtures::TEST_CONFIG) }

  def matched_subjects(match_expressions:, ignore_expressions: [])
    matcher_config = Mutant::Matcher::Config::DEFAULT.with(
      match_expressions: match_expressions,
      ignore_expressions: ignore_expressions
    )

    Mutant::Matcher::Compiler.call(matcher_config).call(bootstrap_env)
  end

  around do |example|
    Dir.chdir(TestApp.root, &example)
  end

  specify 'matches a namespace and nested constants' do
    expressions = matched_subjects(match_expressions: [parse_expression('TestApp::SubjectMatchers')])
      .map { |subject| subject.expression.syntax }
      .sort

    expect(expressions).to eql(
      %w[
        TestApp::SubjectMatchers::Nested::Child#gamma
        TestApp::SubjectMatchers::Prepended#prepended_instance
        TestApp::SubjectMatchers::Root#alpha
        TestApp::SubjectMatchers::Root.beta
      ]
    )
  end

  specify 'matches a recursive namespace' do
    expressions = matched_subjects(match_expressions: [parse_expression('TestApp::SubjectMatchers*')])
      .map { |subject| subject.expression.syntax }
      .sort

    expect(expressions).to eql(
      %w[
        TestApp::SubjectMatchers::Nested::Child#gamma
        TestApp::SubjectMatchers::Prepended#prepended_instance
        TestApp::SubjectMatchers::Root#alpha
        TestApp::SubjectMatchers::Root.beta
      ]
    )
  end

  specify 'matches an instance method exactly' do
    expressions = matched_subjects(match_expressions: [parse_expression('TestApp::SubjectMatchers::Root#alpha')])
      .map { |subject| subject.expression.syntax }
      .sort

    expect(expressions).to eql(['TestApp::SubjectMatchers::Root#alpha'])
  end

  specify 'matches a singleton method exactly' do
    expressions = matched_subjects(match_expressions: [parse_expression('TestApp::SubjectMatchers::Root.beta')])
      .map { |subject| subject.expression.syntax }
      .sort

    expect(expressions).to eql(['TestApp::SubjectMatchers::Root.beta'])
  end

  specify 'matches all subjects in a source glob' do
    expressions = matched_subjects(match_expressions: [parse_expression('source:lib/test_app/subjects.rb')])
      .map { |subject| subject.expression.syntax }
      .sort

    expect(expressions).to eql(
      %w[
        TestApp::SubjectMatchers::Nested::Child#gamma
        TestApp::SubjectMatchers::Prepended#prepended_instance
        TestApp::SubjectMatchers::Root#alpha
        TestApp::SubjectMatchers::Root.beta
      ]
    )
  end

  specify 'composes ignore expressions with namespace subjects' do
    expressions = matched_subjects(
      match_expressions: [parse_expression('TestApp::SubjectMatchers')],
      ignore_expressions: [parse_expression('TestApp::SubjectMatchers::Root')]
    ).map { |subject| subject.expression.syntax }.sort

    expect(expressions).to eql(
      %w[
        TestApp::SubjectMatchers::Nested::Child#gamma
        TestApp::SubjectMatchers::Prepended#prepended_instance
      ]
    )
  end

  specify 'composes ignore expressions with source matchers' do
    expressions = matched_subjects(
      match_expressions: [
        parse_expression('TestApp::Literal'),
        parse_expression('TestApp::SubjectMatchers')
      ],
      ignore_expressions: [parse_expression('source:lib/test_app/subjects.rb')]
    ).map { |subject| subject.expression.syntax }.sort

    expect(expressions).to eql(
      %w[
        TestApp::Literal#boolean
        TestApp::Literal#command
        TestApp::Literal#float
        TestApp::Literal#string
        TestApp::Literal#symbol
        TestApp::Literal#uncovered_string
        TestApp::Literal.string
      ]
    )
  end
end

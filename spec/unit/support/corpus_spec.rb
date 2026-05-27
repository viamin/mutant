# frozen_string_literal: true

require 'open3'
require 'rbconfig'

RSpec.describe 'spec/support/corpus.rb' do
  let(:ruby) { RbConfig.ruby }
  let(:command) { [ruby, '-Ilib:spec', '-e', "require './spec/support/corpus'"] }

  it 'loads yaml when required directly' do
    stdout, stderr, status = Open3.capture3(*command, chdir: MutantSpec::ROOT.to_s)

    expect(status.success?).to be(true), <<~MESSAGE
      stdout: #{stdout}
      stderr: #{stderr}
    MESSAGE
  end
end

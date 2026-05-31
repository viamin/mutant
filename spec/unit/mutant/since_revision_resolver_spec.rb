# frozen_string_literal: true

require 'mutant/since_revision_resolver'

RSpec.describe Mutant::SinceRevisionResolver do
  let(:object) { described_class.new(capture, kernel) }

  let(:capture) { class_double(Open3) }
  let(:kernel) { class_double(Kernel) }

  describe '#call' do
    subject { object.call(input_revision) }

    let(:status) { instance_double(Process::Status, success?: true) }

    context 'when the provided revision is valid' do
      let(:input_revision) { 'base_sha' }

      before do
        expect(kernel).to receive(:system)
          .with(
            'git',
            'rev-parse',
            '--verify',
            'base_sha^{commit}',
            out: File::NULL,
            err: File::NULL
          )
          .and_return(true)
      end

      it { should eql('base_sha') }
    end

    context 'when the provided revision is invalid and origin/main is available' do
      let(:input_revision) { 'invalid' }

      before do
        expect_revision('invalid', false)
        expect_revision('origin/main', true)
        expect(capture).to receive(:capture2)
          .with('git', 'merge-base', 'HEAD', 'origin/main', binmode: true)
          .and_return(["merge_base\n", status])
        expect_revision('merge_base', true)
      end

      it { should eql('merge_base') }
    end

    context 'when origin/main is unavailable and main is available' do
      let(:input_revision) { nil }

      before do
        expect_revision('origin/main', false)
        expect_revision('main', true)
        expect(capture).to receive(:capture2)
          .with('git', 'merge-base', 'HEAD', 'main', binmode: true)
          .and_return(["main_merge_base\n", status])
        expect_revision('main_merge_base', true)
      end

      it { should eql('main_merge_base') }
    end

    context 'when merge-base cannot be resolved' do
      let(:input_revision) { '' }
      let(:status)         { instance_double(Process::Status, success?: false) }

      before do
        expect_revision('origin/main', true)
        expect(capture).to receive(:capture2)
          .with('git', 'merge-base', 'HEAD', 'origin/main', binmode: true)
          .and_return(['', status])
        expect_revision('main', false)
        expect_revision('HEAD~1', true)
      end

      it { should eql('HEAD~1') }
    end

    context 'when no fallback revision is valid' do
      let(:input_revision) { 'missing' }

      before do
        expect_revision('missing', false)
        expect_revision('origin/main', false)
        expect_revision('main', false)
        expect_revision('HEAD~1', false)
      end

      it { should be(nil) }
    end
  end

  def expect_revision(revision, value)
    expect(kernel).to receive(:system)
      .with(
        'git',
        'rev-parse',
        '--verify',
        "#{revision}^{commit}",
        out: File::NULL,
        err: File::NULL
      )
      .and_return(value)
  end
end

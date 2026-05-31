# frozen_string_literal: true

describe Mutant::Repository::Diff do
  describe Mutant::Repository::DiffCommandResult do
    subject(:output?) do
      described_class.new(
        command: command,
        stdout:  stdout,
        stderr:  stderr,
        status:  status
      ).output?
    end

    let(:command) { %w[git diff] }
    let(:stderr)  { instance_double(String) }
    let(:status)  { instance_double(Process::Status, success?: success?) }

    context 'when the command fails with output' do
      let(:success?) { false }
      let(:stdout)   { 'diff output' }

      it { should be(false) }
    end

    context 'when the command succeeds with empty output' do
      let(:success?) { true }
      let(:stdout)   { '' }

      it { should be(false) }
    end

    context 'when the command succeeds with output' do
      let(:success?) { true }
      let(:stdout)   { 'diff output' }

      it { should be(true) }
    end
  end

  describe Mutant::Repository::DiffLocation do
    subject(:touched_by_hunk?) do
      described_class.new(path: Pathname.new('/foo/bar.rb'), line_range: line_range)
        .touched_by_hunk?(start_line, line_count)
    end

    let(:line_range) { 5..7 }

    context 'when the hunk has zero added lines' do
      let(:start_line) { 5 }
      let(:line_count) { 0 }

      it { should be(false) }
    end

    context 'when the hunk ends before the location starts' do
      let(:start_line) { 1 }
      let(:line_count) { 3 }

      it { should be(false) }
    end

    context 'when the hunk starts after the location ends' do
      let(:start_line) { 8 }
      let(:line_count) { 2 }

      it { should be(false) }
    end

    context 'when the hunk overlaps the start of the location' do
      let(:start_line) { 3 }
      let(:line_count) { 3 }

      it { should be(true) }
    end

    context 'when the hunk overlaps the end of the location' do
      let(:start_line) { 7 }
      let(:line_count) { 2 }

      it { should be(true) }
    end
  end

  let(:object) do
    described_class.new(
      config: config,
      from:   'from_rev',
      to:     'to_rev'
    )
  end

  let(:config) do
    instance_double(
      Mutant::Config,
      kernel:   kernel,
      open3:    open3,
      pathname: pathname
    )
  end

  let(:pathname) { class_double(Pathname, pwd: pwd) }
  let(:open3)    { class_double(Open3)              }
  let(:kernel)   { class_double(Kernel)             }
  let(:pwd)      { Pathname.new('/foo')             }

  describe '#touches?' do
    let(:path)       { Pathname.new('/foo/bar.rb')      }
    let(:line_range) { 1..2                             }

    subject { object.touches?(path, line_range) }

    shared_context 'test if git tracks the file' do
      before do
        # rubocop:disable Lint/UnneededSplatExpansion
        expect(config.kernel).to receive(:system)
          .ordered
          .with(
            *%W[git ls-files --error-unmatch -- #{path}],
            out: File::NULL,
            err: File::NULL
          ).and_return(git_ls_success?)
      end
    end

    context 'when file is in a different subdirectory' do
      let(:path) { Pathname.new('/baz/bar.rb') }

      before do
        expect(config.kernel).to_not receive(:system)
      end

      it { should be(false) }
    end

    context 'when file is NOT tracked in repository' do
      let(:git_ls_success?) { false }

      include_context 'test if git tracks the file'

      it { should be(false) }
    end

    context 'when file is tracked in repository' do
      let(:git_ls_success?) { true                                                 }
      let(:status)          { instance_double(Process::Status, success?: success?) }
      let(:stdout)          { instance_double(String, empty?: stdout_empty?)       }
      let(:stderr)          { ''                                                   }
      let(:stdout_empty?)   { false                                                }

      include_context 'test if git tracks the file'

      before do
        expect(config.open3).to receive(:capture3)
          .ordered
          .with(*expected_git_log_command, binmode: true)
          .and_return([stdout, stderr, status])
      end

      let(:expected_git_log_command) do
        %W[git log from_rev..to_rev --ignore-all-space -L 1,2:#{path}]
      end

      context 'on failure of git log command' do
        let(:success?) { false }

        it 'raises error' do
          expect { subject }.to raise_error(
            Mutant::Repository::RepositoryError,
            "Command #{expected_git_log_command} failed!"
          )
        end

        context 'when git rejects a line range that only exists in the new revision' do
          let(:stdout)                { instance_double(String, empty?: true)               }
          let(:stderr)                { 'fatal: file /foo/bar.rb has only 1 lines'          }
          let(:diff_status)           { instance_double(Process::Status, success?: true)    }
          let(:diff_stdout)           { "@@ -1,0 +1,2 @@\n+foo\n+bar\n"                     }
          let(:expected_git_diff_command) { %W[git diff --unified=0 from_rev..to_rev -- #{path}] }

          before do
            expect(config.open3).to receive(:capture3)
              .ordered
              .with(*expected_git_diff_command, binmode: true)
              .and_return([diff_stdout, instance_double(String), diff_status])
          end

          it { should be(true) }

          context 'when git diff also fails' do
            let(:diff_status) { instance_double(Process::Status, success?: false) }

            it 'raises error' do
              expect { subject }.to raise_error(
                Mutant::Repository::RepositoryError,
                "Command #{expected_git_diff_command} failed!"
              )
            end
          end

          context 'when fallback diff only contains zero-length hunks' do
            let(:diff_stdout) { "@@ -1,0 +1,0 @@\n" }

            it { should be(false) }
          end

          context 'when fallback diff includes non-hunk lines before a matching hunk' do
            let(:diff_stdout) { "diff --git a/foo b/foo\n@@ -1,0 +1,2 @@\n+foo\n+bar\n" }

            it { should be(true) }
          end
        end
      end

      context 'on suuccess of git command' do
        let(:success?) { true }

        context 'on empty stdout' do
          let(:stdout_empty?) { true }

          it { should be(false) }
        end

        context 'on non empty stdout' do
          let(:stdout_empty?) { false }

          it { should be(true) }
        end
      end

    end
  end

  describe '#parse_hunk' do
    subject { object.send(:parse_hunk, line) }

    context 'with an explicit line count' do
      let(:line) { '@@ -4,0 +7,2 @@' }

      it { should eql([7, 2]) }
    end

    context 'without an explicit line count' do
      let(:line) { '@@ -4 +7 @@' }

      it { should eql([7, 1]) }
    end

    context 'with a zero-length added hunk' do
      let(:line) { '@@ -4,2 +7,0 @@' }

      it { should eql([7, 0]) }
    end

    context 'with a malformed hunk header' do
      let(:line) { 'not a hunk header' }

      it 'raises an error' do
        expect { subject }.to raise_error(
          Mutant::Repository::RepositoryError,
          'Cannot parse diff hunk: "not a hunk header"'
        )
      end
    end
  end
end

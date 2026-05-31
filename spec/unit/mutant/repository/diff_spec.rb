# frozen_string_literal: true

describe Mutant::Repository::Diff do
  let(:object) do
    described_class.new(
      config: config,
      from:   'from_rev',
      to:     'HEAD'
    )
  end

  let(:config) do
    instance_double(
      Mutant::Config,
      open3:    open3,
      pathname: pathname
    )
  end

  let(:pathname) { class_double(Pathname, pwd: pwd) }
  let(:open3)    { class_double(Open3)              }
  let(:pwd)      { Pathname.new('/foo')             }
  let(:status)   { instance_double(Process::Status, success?: true) }

  let(:rev_parse_from_stdout) { instance_double(String, strip: 'sha_from') }
  let(:rev_parse_to_stdout)   { instance_double(String, strip: 'sha_to')   }
  let(:rev_parse_status)      { instance_double(Process::Status, success?: true) }

  let(:expected_diff_command) do
    %w[git diff sha_from...sha_to]
  end

  shared_context 'setup rev-parse commands' do
    before do
      expect(config.open3).to receive(:capture2)
        .ordered
        .with(*%w[git rev-parse --verify from_rev], binmode: true)
        .and_return([rev_parse_from_stdout, rev_parse_status])

      expect(config.open3).to receive(:capture2)
        .ordered
        .with(*%w[git rev-parse --verify HEAD], binmode: true)
        .and_return([rev_parse_to_stdout, rev_parse_status])
    end
  end

  shared_context 'setup diff command' do
    include_context 'setup rev-parse commands'

    before do
      expect(config.open3).to receive(:capture2)
        .ordered
        .with(*expected_diff_command, binmode: true)
        .and_return([diff_output, status])
    end
  end

  describe '#touches?' do
    subject { object.touches?(location) }

    let(:path)       { Pathname.new('/foo/lib/bar.rb') }
    let(:line_range) { 1..2 }
    let(:location) do
      Mutant::Repository::SubjectLocation.new(path, line_range)
    end

    context 'when file is in a different subdirectory' do
      let(:path) { Pathname.new('/baz/bar.rb') }

      it 'does not run git commands' do
        expect(config.open3).to_not receive(:capture2)

        expect(subject).to be(false)
      end
    end

    context 'when git rev-parse fails for "from" ref' do
      let(:rev_parse_status) { instance_double(Process::Status, success?: false) }

      before do
        expect(config.open3).to receive(:capture2)
          .ordered
          .with(*%w[git rev-parse --verify from_rev], binmode: true)
          .and_return([rev_parse_from_stdout, rev_parse_status])
      end

      it 'raises error' do
        expect { subject }.to raise_error(
          Mutant::Repository::RepositoryError,
          'Command ["git", "rev-parse", "--verify", "from_rev"] failed!'
        )
      end
    end

    context 'when git diff command fails' do
      let(:diff_output) { '' }
      let(:status)      { instance_double(Process::Status, success?: false) }

      include_context 'setup diff command'

      it 'raises error' do
        expect { subject }.to raise_error(
          Mutant::Repository::RepositoryError,
          "Command #{expected_diff_command} failed!"
        )
      end
    end

    context 'when diff is empty' do
      let(:diff_output) { '' }

      include_context 'setup diff command'

      it { should be(false) }
    end

    context 'when file is not in the diff' do
      let(:diff_output) do
        <<~DIFF
          diff --git a/lib/other.rb b/lib/other.rb
          --- a/lib/other.rb
          +++ b/lib/other.rb
          @@ -10,3 +10,4 @@ context
          +new line
        DIFF
      end

      include_context 'setup diff command'

      it { should be(false) }
    end

    context 'when file is in diff with overlapping hunk' do
      let(:diff_output) do
        <<~DIFF
          diff --git a/lib/bar.rb b/lib/bar.rb
          --- a/lib/bar.rb
          +++ b/lib/bar.rb
          @@ -1,3 +1,4 @@
          context
          +new line
          context
        DIFF
      end

      include_context 'setup diff command'

      it { should be(true) }
    end

    context 'when file is in diff but hunks do not overlap' do
      let(:line_range) { 50..60 }

      let(:diff_output) do
        <<~DIFF
          diff --git a/lib/bar.rb b/lib/bar.rb
          --- a/lib/bar.rb
          +++ b/lib/bar.rb
          @@ -10,3 +10,4 @@
          context
          +new line
          context
        DIFF
      end

      include_context 'setup diff command'

      it { should be(false) }
    end

    context 'when file range ends immediately before diff hunk starts' do
      let(:line_range) { 1..9 }

      let(:diff_output) do
        <<~DIFF
          diff --git a/lib/bar.rb b/lib/bar.rb
          --- a/lib/bar.rb
          +++ b/lib/bar.rb
          @@ -10,3 +10,4 @@
          context
          +new line
        DIFF
      end

      include_context 'setup diff command'

      it { should be(false) }
    end

    context 'when file range touches the diff hunk boundary' do
      let(:line_range) { 13..20 }

      let(:diff_output) do
        <<~DIFF
          diff --git a/lib/bar.rb b/lib/bar.rb
          --- a/lib/bar.rb
          +++ b/lib/bar.rb
          @@ -10,3 +10,4 @@
          context
          +new line
        DIFF
      end

      include_context 'setup diff command'

      it { should be(true) }
    end

    context 'when file is newly added' do
      let(:line_range) { 100..200 }

      let(:diff_output) do
        <<~DIFF
          diff --git a/lib/bar.rb b/lib/bar.rb
          new file mode 100644
          --- /dev/null
          +++ b/lib/bar.rb
          @@ -0,0 +1,5 @@
          +line 1
          +line 2
        DIFF
      end

      include_context 'setup diff command'

      it { should be(true) }
    end

    context 'when hunk has an implicit one-line count' do
      let(:line_range) { 20..20 }

      let(:diff_output) do
        <<~DIFF
          diff --git a/lib/bar.rb b/lib/bar.rb
          --- a/lib/bar.rb
          +++ b/lib/bar.rb
          @@ -10 +20 @@
          +new line
        DIFF
      end

      include_context 'setup diff command'

      it { should be(true) }
    end

    context 'when file is deleted' do
      let(:diff_output) do
        <<~DIFF
          diff --git a/lib/bar.rb b/lib/bar.rb
          deleted file mode 100644
          --- a/lib/bar.rb
          +++ /dev/null
          @@ -1,3 +0,0 @@
          -old line
        DIFF
      end

      include_context 'setup diff command'

      it { should be(false) }
    end

    context 'with multiple hunks in same file' do
      let(:line_range) { 30..35 }

      let(:diff_output) do
        <<~DIFF
          diff --git a/lib/bar.rb b/lib/bar.rb
          --- a/lib/bar.rb
          +++ b/lib/bar.rb
          @@ -10,3 +10,4 @@
          context
          +new line
          @@ -30,3 +31,4 @@
          context
          +other new line
        DIFF
      end

      include_context 'setup diff command'

      it { should be(true) }
    end

    context 'with multiple files in diff' do
      let(:diff_output) do
        <<~DIFF
          diff --git a/lib/other.rb b/lib/other.rb
          --- a/lib/other.rb
          +++ b/lib/other.rb
          @@ -10,3 +10,4 @@
          +new line
          diff --git a/lib/bar.rb b/lib/bar.rb
          --- a/lib/bar.rb
          +++ b/lib/bar.rb
          @@ -1,3 +1,4 @@
          +added
        DIFF
      end

      include_context 'setup diff command'

      it { should be(true) }
    end
  end
end

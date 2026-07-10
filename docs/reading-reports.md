Reading Reports
===============

Mutation output is grouped by selection groups. Each group contains three sections:

1. An identifier for the current group.

   **Format**:

   ```text
   [SUBJECT EXPRESSION]:[SOURCE LOCATION]:[LINENO]
   ```

   **Example**:

   ```text
   Book#add_page:Book#add_page:/home/dev/mutant-examples/lib/book.rb:18
   ```

2. A list of specs that mutant ran to try to kill mutations for the current group.

   **Format**:

   ```text
   - [INTEGRATION]:0:[SPEC LOCATION]:[SPEC DESCRIPTION]
   - [INTEGRATION]:1:[SPEC LOCATION]:[SPEC DESCRIPTION]
   ```

   **Example**:

   ```text
   - rspec:0:./spec/unit/book_spec.rb:9/Book#add_page should return self
   - rspec:1:./spec/unit/book_spec.rb:13/Book#add_page should add page to book
   ```

3. A list of unkilled mutations diffed against the original unparsed source

   **Format**:

   ```text
   [MUTATION TYPE]:[SUBJECT EXPRESSION]:[SOURCE LOCATION]:[SOURCE LINENO]:[IDENTIFIER]
   [DIFF]
   -----------------------
   ```

   - `[MUTATION TYPE]` will be one of the following:
      - `evil` - a mutation of your source was not killed by your tests
      - `neutral` your original source was injected and one or more tests failed
   - `[IDENTIFIER]` - Unique identifier for this mutation

   **Example**:

   ```diff
   evil:Book#add_page:Book#add_page:/home/dev/mutant-examples/lib/book.rb:18:01f69
   @@ -1,6 +1,6 @@
    def add_page(page)
   -  @pages << page
   +  @pages
      @index[page.number] = page
      self
    end
   -----------------------
   evil:Book#add_page:Book#add_page:/home/dev/mutant-examples/lib/book.rb:18:b1ff2
   @@ -1,6 +1,6 @@
    def add_page(page)
   -  @pages << page
   +  self
      @index[page.number] = page
      self
    end
   -----------------------
   ```

## Machine readable output

In addition to the human readable CLI output documented above, mutant writes a
machine readable YAML result file on every run. This makes it possible to
inspect, archive, or post-process past runs programmatically.

### Location

Result files are written to the results directory, defaulting to
`.mutant/results/`. Each run produces one file named:

```text
.mutant/results/<timestamp>-<sha>.yml
```

Where `<timestamp>` is the run start time in UTC formatted as
`%Y%m%dT%H%M%SZ` (for example `20240101T120000Z`) and `<sha>` is the
abbreviated commit SHA the run was executed against (the first 7 characters of
`git rev-parse HEAD`, or `unknown` when git is unavailable).

### Overriding the output location

The `--results-dir DIR` flag overrides the destination directory:

```text
mutant run --results-dir path/to/results -- Foo
```

### Schema

The YAML document is a hash with the following top level fields:

* `ran_at` — the run start time (UTC).
* `git_ref` — the commit SHA the run was executed against.
* `since` — the revision used as the `--since` baseline, if any.
* `total_mutations` — total number of mutations evaluated.
* `killed` — number of mutations killed by the tests.
* `alive` — number of mutations that survived (were not killed).
* `errored` — number of mutations that errored during evaluation.
* `alive_mutations` — list of surviving mutations (see below).
* `errored_mutations` — list of mutations that errored (see below).

Each entry in `alive_mutations` is a hash with:

* `subject` — the subject identification.
* `subject_path` — the source file path of the subject.
* `source_line` — the source line number of the subject.
* `mutation_diff` — the unified diff of the mutation against the original source.

Each entry in `errored_mutations` is a hash with `subject` and `error` keys
describing the failure encountered while evaluating the mutation.

### Reviewing past runs

The `mutant session` subcommand reads previously written result files so they
can be reviewed without re-running mutant.

* `mutant session list` — lists all sessions found in the results directory.
* `mutant session show <id>` — shows the details of a specific session, where
  `<id>` is the file name stem of a result file (the `<timestamp>-<sha>` part,
  without the `.yml` suffix).

Run `mutant help session` for a summary of these subcommands.

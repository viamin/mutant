mutant
======

## What is Mutant?

Mutant is a mutation testing tool for Ruby. Mutation testing is a technique to verify semantic coverage of your code.

## Why do I want it?

Mutant adds to your toolbox: Detection of uncovered semantics in your code.
Coverage becomes a meaninful metric!

On each detection of uncovered semantics you have the opportunity to:

* Delete dead code, as you do not want the extra semantics not specified by the tests
* Add (or improve a test) to cover the unwanted semantics.
* Learn something new about the semantics of Ruby and your direct and indirect dependencies.

## How Do I use it?

* Start with reading the [nomenclature](/docs/nomenclature.md) documentation.
* Than select and setup your [integration](/docs/nomenclature.md#interation), also make sure
  you can reproduce the examples in the integration specific documentation.
* Identify your preferred mutation testing strategy. Its recommended to start at the commit level,
  to test only the code you had been touching. See the [incremental](#only-mutating-changed-code)
  mutation testing documentation.

Topics
------

* [Nomenclature](/docs/nomenclature.md)
* [Reading Reports](/docs/reading-reports.md)
* [Known Problems](/docs/known-problems.md)
* [Limitations](/docs/limitations.md)
* [Concurrency](/docs/concurrency.md)
* [Mutators](/docs/mutators.md)
* [Mutator Coverage](/docs/mutator-coverage.md)
* [Rspec Integration](/docs/mutant-rspec.md)
* [Minitest Integration](/docs/mutant-minitest.md)

Subcommands
-----------

Mutant uses a subcommand-based CLI. The available subcommands are:

### `mutant run [options] MATCH_EXPRESSION ...`

Run mutation testing. This is the primary command. All options from the previous single-command form are accepted here.

```
bundle exec mutant run --use rspec --include lib --require myapp MyApp*
```

### `mutant environment [options]`

Print the resolved configuration (after merging CLI flags) and exit. Useful for debugging which settings are active.

```
bundle exec mutant environment --use rspec --include lib MyApp*
```

### `mutant session <subcommand>`

Inspect mutation testing session results.

* `mutant session list` — List sessions
* `mutant session show <id>` — Show details of a specific session

### `mutant help [subcommand]`

Display help for mutant or a specific subcommand.

```
bundle exec mutant help run
```

### Backward Compatibility

Invoking `mutant` without a subcommand (e.g. `mutant --use rspec MyApp*`) is temporarily accepted as an alias for `mutant run`, but prints a deprecation warning. This alias will be removed in a future release.

Mutation-Operators
------------------

Mutant supports a wide range of mutation operators. The currently shipped operator families are documented in [docs/mutators.md](/docs/mutators.md), and the modern-Ruby coverage gaps tracked by issue `#18` are documented in [docs/mutator-coverage.md](/docs/mutator-coverage.md).

The local `meta/` directory remains the exhaustive behavioral specification. It is arranged by parser AST node type; refer to parser's [AST documentation](https://github.com/whitequark/parser/blob/master/doc/AST_FORMAT.md) in doubt.

There is no easy and universal way to count the number of mutation operators a tool supports.

Neutral (noop) Tests
--------------------

Mutant will also test the original, unmutated, version your code. This ensures that mutant is able to properly setup and run your tests.
If an error occurs while mutant/rspec is running testing the original code, you will receive an error like the following:
```
--- Neutral failure ---
Original code was inserted unmutated. And the test did NOT PASS.
Your tests do not pass initially or you found a bug in mutant / unparser.
...
Test Output:
marshal data too short
```
Currently, troubleshooting these errors requires using a debugger and/or modyifying mutant to print out the error. You will want to rescue and inspect exceptions raised in this method: lib/mutant/integration/rspec.rb:call

Configuration
-------------

Mutant will load `.mutant.yml` from the project root when present. CLI flags override YAML values such as `--jobs` and `--since`.

Supported top-level keys:

```yaml
integration: rspec
requires:
  - ./config/environment
environment_variables:
  RAILS_ENV: test
  COVERAGE: "false"
jobs: 4
fail_fast: true
coverage_criteria:
  timeout: false
  process_abort: false
  test_result: true
matcher:
  subjects:
    - "MyApp::Critical*"
    - "MyApp::Secrets#fetch"
  ignore:
    - "app/admin/**/*.rb"
results_dir: tmp/mutant
```

Defaults:

* `jobs: 1`
* `fail_fast: false`
* `coverage_criteria.process_abort: false`
* `coverage_criteria.timeout: false`
* `coverage_criteria.test_result: true`

Only Mutating Changed Code
--------------------------

Running mutant for the first time on an existing codebase can be a rather disheartening experience due to the large number of alive mutations found! Mutant has a setting that can help. Using the `--since` argument, mutant will only mutate code that has been modified. This allows you to introduce mutant into an existing code base without drowning in errors.

### How it works

`--since <git-ref>` computes the diff from the merge-base of `<git-ref>` and `HEAD` via `git diff <git-ref>...HEAD`. Any subject (method, singleton method, class/module body) whose source range overlaps a changed hunk is included in the mutation set. Newly added files include all their subjects. Deleted files are skipped. The result is intersected with the configured subject matchers, so `--since` never expands beyond what the match expressions would have matched.

### Example: standalone gem

Mutate all code changed between `master` and the current branch:

```
bundle exec mutant run --include lib --require virtus --since master --use rspec Virtus::Attribute#type
```

### Example: Rails app in CI

Run incremental mutation testing on a pull request, only mutating subjects touched by the PR diff:

```
bundle exec mutant \
  --include app \
  --include lib \
  --require config/environment \
  --since origin/main \
  --use rspec \
  --jobs 4 \
  "MyApp*"
```

When the intersection of diff-touched subjects and matched subjects is empty, mutant exits `0` with an informational message.

Note that this feature requires at least git `2.13.0`.

Subject Matchers
----------------

Mutant accepts subject matcher expressions as CLI positional arguments and through matcher configuration.

| Syntax | Meaning |
| --- | --- |
| `MyApp::Foo` | All methods on `MyApp::Foo` and its nested constants. |
| `MyApp::Foo*` | `MyApp::Foo` and all constants under that namespace. |
| `MyApp::Foo#bar` | Instance method `MyApp::Foo#bar` only. |
| `MyApp::Foo.bar` | Singleton method `MyApp::Foo.bar` only. |
| `source:app/models/**/*.rb` | All subjects defined in files matching the glob. |

Use `--include-subject EXPRESSION` to append additional subject matchers from the CLI without replacing any configured matcher list.

Presentations
-------------

There are some presentations about mutant in the wild:

* [RailsConf 2014](http://railsconf.com/) / http://confreaks.com/videos/3333-railsconf-mutation-testing-with-mutant
* [Wrocloverb 2014](http://wrocloverb.com/) / https://www.youtube.com/watch?v=rz-lFKEioLk
* [eurucamp 2013](http://2013.eurucamp.org/) / FrOSCon-2013 http://slid.es/markusschirp/mutation-testing
* [Cologne.rb](http://www.colognerb.de/topics/mutation-testing-mit-mutant) / https://github.com/DonSchado/colognerb-on-mutant/blob/master/mutation_testing_slides.pdf

Blog posts
----------

Sorted by recency:

* [A deep dive into mutation testing and how the Mutant gem works][troessner]
* [Keep calm and kill mutants (December, 2015)][itransition]
* [How to write better code using mutation testing (November 2015)][blockscore]
* [How good are your Ruby tests? Testing your tests with mutant (June 2015)][arkency1]
* [Mutation testing and continuous integration (May 2015)][arkency2]
* [Why I want to introduce mutation testing to the `rails_event_store` gem (April 2015)][arkency3]
* [Mutation testing with mutant (April 2014)][sitepoint]
* [Mutation testing with mutant (January 2013)][solnic]

[troessner]: https://troessner.svbtle.com/kill-all-the-mutants-a-deep-dive-into-mutation-testing-and-how-the-mutant-gem-works
[itransition]: https://github.com/maksar/mentat
[blockscore]: https://blog.blockscore.com/how-to-write-better-code-using-mutation-testing/
[sitepoint]: http://www.sitepoint.com/mutation-testing-mutant/
[arkency1]: http://blog.arkency.com/2015/06/how-good-are-your-ruby-tests-testing-your-tests-with-mutant/
[arkency2]: http://blog.arkency.com/2015/05/mutation-testing-and-continuous-integration/
[arkency3]: http://blog.arkency.com/2015/04/why-i-want-to-introduce-mutation-testing-to-the-rails-event-store-gem/
[solnic]: http://solnic.eu/2013/01/23/mutation-testing-with-mutant.html

Credits
-------

* [Markus Schirp (mbj)](https://github.com/mbj)
* A gist, now removed, from [dkubb](https://github.com/dkubb) showing ideas.
* Older abandoned [mutant](https://github.com/txus/mutant). For motivating me doing this one.
* [heckle](https://github.com/seattlerb/heckle). For getting me into mutation testing.

Contributing
-------------

* Fork the project.
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a
  future version unintentionally.
* Commit, do not mess with Rakefile or version
  (if you want to have your own version, that is fine but bump version in a commit by itself I can ignore when I pull)
* Send me a pull request. Bonus points for topic branches.

License
-------

See LICENSE file.

Licensing
---------

viamin/mutant is MIT-licensed. There is no commercial gate, no license key, and no usage restriction. Use on open-source or proprietary code freely under the terms of the LICENSE file.

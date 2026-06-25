# Changelog

## [0.9.1](https://github.com/viamin/mutant/compare/v0.9.0...v0.9.1) (2026-06-25)


### Bug Fixes

* sync Gemfile.lock PATH spec version with v0.9.0 release ([#57](https://github.com/viamin/mutant/issues/57)) ([7c9dd13](https://github.com/viamin/mutant/commit/7c9dd13fb8f12438d1d51e12394d5821be6def9b))

## [0.9.0](https://github.com/viamin/mutant/compare/v0.8.25...v0.9.0) (2026-06-24)


### Features

* add Dependabot configuration for automated dependency updates ([#7](https://github.com/viamin/mutant/issues/7)) ([daf5a96](https://github.com/viamin/mutant/commit/daf5a96dd667c7f2bce0138ef0287dae5788f51d))
* add explicit github token permissions to ci workflow ([#37](https://github.com/viamin/mutant/issues/37)) ([f1c4bbf](https://github.com/viamin/mutant/commit/f1c4bbf0ce99a87ec7ba181db0fb82315bbda7ab))
* add explicit permissions to ci workflow ([#38](https://github.com/viamin/mutant/issues/38)) ([4fbcf69](https://github.com/viamin/mutant/commit/4fbcf69ad93543824a40e1b23bf0e48b2717872f))
* Add release-please for automated release tagging and notes ([#21](https://github.com/viamin/mutant/issues/21)) ([07d8c9f](https://github.com/viamin/mutant/commit/07d8c9fda55401ef42a5a255b1489e3b1dd3f88d))
* add scope-awareness to node mutators ([08cd144](https://github.com/viamin/mutant/commit/08cd144bb7800483af127a8c118ad3bfd5d63825))
* Do not implement --usage opensource/--usage commercial flag; document MIT licensing ([#26](https://github.com/viamin/mutant/issues/26)) ([f96971e](https://github.com/viamin/mutant/commit/f96971e46efde515cda2bc956eed4ca756d11f05))
* Emit structured per-run results to .mutant/results/*.yml ([#42](https://github.com/viamin/mutant/issues/42)) ([c00be4a](https://github.com/viamin/mutant/commit/c00be4a4e9e41a2300424ed212463858bb1288a1))
* Establish mutation coverage for scope-detection subjects ([#56](https://github.com/viamin/mutant/issues/56)) ([7a1cad4](https://github.com/viamin/mutant/commit/7a1cad4c26b562834d43a0d402909926e34d7847))
* Foundation — dependency bumps, Ruby 3.4 CI, dynamic parser selection, compatibility fixes ([#47](https://github.com/viamin/mutant/issues/47)) ([e83d007](https://github.com/viamin/mutant/commit/e83d00731e539617d1db02e1e5f95a74c7fa625d))
* Implement --since &lt;git-ref&gt; incremental mode ([#33](https://github.com/viamin/mutant/issues/33)) ([6663ac0](https://github.com/viamin/mutant/commit/6663ac038e6b9132c688f972c69a3d2028626169))
* Meta: mutation operator coverage tracking ([#27](https://github.com/viamin/mutant/issues/27)) ([c92a33a](https://github.com/viamin/mutant/commit/c92a33ade4ce6d21dd27dd375529fc44076584df))
* migrate CircleCI configuration to GitHub Actions ([#5](https://github.com/viamin/mutant/issues/5)) ([b7e51ef](https://github.com/viamin/mutant/commit/b7e51ef457534117ba00c192e0d6727fc8f1a0e5))
* Modernize mutant-rspec integration for RSpec 3.10+ and 4.x ([#34](https://github.com/viamin/mutant/issues/34)) ([88130c3](https://github.com/viamin/mutant/commit/88130c3bcd6c3f92261af980c52742527c3b96f3))
* modernize project — upgrade Ruby, dependencies, and tooling ([#6](https://github.com/viamin/mutant/issues/6)) ([01da59a](https://github.com/viamin/mutant/commit/01da59a1f76ff2d69ce058f33e6070dd3bcc1162))
* Remove upstream-specific sections from README ([#22](https://github.com/viamin/mutant/issues/22)) ([e893c4b](https://github.com/viamin/mutant/commit/e893c4b68a8b4b743094c88fb3179b42a2955517)), closes [#20](https://github.com/viamin/mutant/issues/20)
* Restore --jobs N parallel mutation runner ([#23](https://github.com/viamin/mutant/issues/23)) ([0a0985c](https://github.com/viamin/mutant/commit/0a0985c1d48663fa4c3f8fea17b589804caeedb6))
* Subcommand CLI: mutant run, mutant environment, mutant session ([#29](https://github.com/viamin/mutant/issues/29)) ([0a025d6](https://github.com/viamin/mutant/commit/0a025d6f1e4c168ef99c8dde1e481aaec0a88e98))
* Subject matcher expression syntax: wildcards, methods, source-path matchers ([#30](https://github.com/viamin/mutant/issues/30)) ([36175bc](https://github.com/viamin/mutant/commit/36175bcee1732dd1085e15be415aba5ed53d5a55))
* Support .mutant.yml config keys: coverage_criteria, fail_fast, jobs, requires, environment_variables, matcher ([#25](https://github.com/viamin/mutant/issues/25)) ([66b4494](https://github.com/viamin/mutant/commit/66b44945c7d76f96fba5d75887cae54545d1c6e3))


### Bug Fixes

* [Security] CodeQL: Workflow does not contain permissions (medium) — code-scanning-alert-5 ([#39](https://github.com/viamin/mutant/issues/39)) ([fd8be6f](https://github.com/viamin/mutant/commit/fd8be6fb4a24451e561365f8307add8f6aafdeef))
* [Security] CodeQL: Workflow does not contain permissions (medium) — code-scanning-alert-7 ([#40](https://github.com/viamin/mutant/issues/40)) ([b17b85c](https://github.com/viamin/mutant/commit/b17b85c6fe45520b0f50a5aed4d262e0ac116e7d))

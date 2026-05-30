# frozen_string_literal: true

RSpec.describe Mutant::Runner do
  describe '#empty_result' do
    let(:env) do
      instance_double(
        Mutant::Env,
        mutations: [],
        subjects:  []
      )
    end

    let(:object) do
      described_class.allocate.tap do |runner|
        runner.instance_variable_set(:@env, env)
      end
    end

    subject { object.send(:empty_result) }

    it 'returns an env result with zero runtime and no subject results' do
      expect(subject).to be_instance_of(Mutant::Result::Env)
      expect(subject.env).to eql(env)
      expect(subject.runtime).to eql(0.0)
      expect(subject.subject_results).to eql([])
    end
  end

  describe '.call' do
    let(:condition_variable) { class_double(ConditionVariable)                 }
    let(:delay)              { instance_double(Float)                          }
    let(:driver)             { instance_double(Mutant::Parallel::Driver)       }
    let(:env_result)         { instance_double(Mutant::Result::Env)            }
    let(:kernel)             { class_double(Kernel)                            }
    let(:mutex)              { class_double(Mutex)                             }
    let(:processor)          { instance_double(Method)                         }
    let(:reporter)           { instance_double(Mutant::Reporter, delay: delay) }
    let(:thread)             { class_double(Thread)                            }

    let(:config) do
      instance_double(
        Mutant::Config,
        condition_variable: condition_variable,
        jobs:               1,
        kernel:             kernel,
        mutex:              mutex,
        reporter:           reporter,
        thread:             thread
      )
    end

    let(:status_a) do
      instance_double(
        Mutant::Parallel::Status,
        done?: false
      )
    end

    let(:status_b) do
      instance_double(
        Mutant::Parallel::Status,
        done?:   true,
        payload: env_result
      )
    end

    def apply
      described_class.call(env)
    end

    context 'when env has mutations' do
      let(:mutation) { instance_double(Mutant::Mutation) }

      let(:env) do
        instance_double(
          Mutant::Env,
          config:    config,
          mutations: [mutation]
        )
      end

      let(:parallel_config) do
        Mutant::Parallel::Config.new(
          condition_variable: condition_variable,
          jobs:               1,
          mutex:              mutex,
          processor:          processor,
          sink:               Mutant::Runner::Sink.new(env),
          source:             Mutant::Parallel::Source::Array.new(env.mutations),
          thread:             thread
        )
      end

      let(:raw_expectations) do
        [
          {
            receiver:  reporter,
            selector:  :start,
            arguments: [env]
          },
          {
            receiver:  env,
            selector:  :method,
            arguments: [:kill],
            reaction:  { return: processor }
          },
          {
            receiver:  Mutant::Parallel,
            selector:  :async,
            arguments: [parallel_config],
            reaction:  { return: driver }
          },
          {
            receiver:  driver,
            selector:  :wait_timeout,
            arguments: [delay],
            reaction:  { return: status_a }
          },
          {
            receiver:  reporter,
            selector:  :progress,
            arguments: [status_a]
          },
          {
            receiver:  driver,
            selector:  :wait_timeout,
            arguments: [delay],
            reaction:  { return: status_b }
          },
          {
            receiver:  reporter,
            selector:  :report,
            arguments: [env_result]
          }
        ]
      end

      it 'returns env result' do
        verify_events { expect(apply).to eql(env_result) }
      end
    end

    context 'when env has no mutations' do
      let(:env) do
        instance_double(
          Mutant::Env,
          config:    config,
          mutations: []
        )
      end

      let(:empty_result) do
        Mutant::Result::Env.new(
          env:             env,
          runtime:         0.0,
          subject_results: []
        )
      end

      let(:raw_expectations) do
        [
          {
            receiver:  reporter,
            selector:  :start,
            arguments: [env]
          },
          {
            receiver:  reporter,
            selector:  :report,
            arguments: [empty_result]
          }
        ]
      end

      it 'returns empty result' do
        verify_events { expect(apply).to eql(empty_result) }
      end

      it 'returns an env result object with no subject results' do
        verify_events do
          result = apply

          expect(result).to be_instance_of(Mutant::Result::Env)
          expect(result.env).to eql(env)
          expect(result.subject_results).to eql([])
          expect(result.runtime).to eql(0.0)
        end
      end
    end
  end
end

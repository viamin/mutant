# frozen_string_literal: true

RSpec.describe Mutant::Runner do
  let(:condition_variable) { class_double(ConditionVariable)                 }
  let(:delay)              { instance_double(Float)                          }
  let(:driver)             { instance_double(Mutant::Parallel::Driver)       }
  let(:env_result)         { instance_double(Mutant::Result::Env)            }
  let(:kernel)             { class_double(Kernel)                            }
  let(:mutex)              { class_double(Mutex)                             }
  let(:partial_env_result) { instance_double(Mutant::Result::Env)            }
  let(:processor)          { instance_double(Method)                         }
  let(:reporter)           { instance_double(Mutant::Reporter, delay: delay) }
  let(:sink)               { instance_double(Mutant::Runner::Sink)           }
  let(:thread)             { class_double(Thread)                            }

  let(:env) do
    instance_double(
      Mutant::Env,
      config:    config,
      mutations: []
    )
  end

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

  let(:parallel_config) do
    Mutant::Parallel::Config.new(
      condition_variable: condition_variable,
      jobs:               1,
      mutex:              mutex,
      processor:          processor,
      sink:               sink,
      source:             Mutant::Parallel::Source::Array.new(env.mutations),
      thread:             thread
    )
  end

  def apply
    described_class.call(env)
  end

  before do
    io_instance = instance_double(Mutant::Result::Env::IO)
    allow(Mutant::Result::Env::IO).to receive(:new).and_return(io_instance)
    allow(io_instance).to receive(:call)
  end

  describe '.call' do
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
          receiver:  Mutant::Runner::Sink,
          selector:  :new,
          arguments: [env],
          reaction:  { return: sink }
        },
        {
          receiver:  Mutant::Parallel,
          selector:  :async,
          arguments: [parallel_config],
          reaction:  { return: driver }
        },
        {
          receiver:  Signal,
          selector:  :trap,
          arguments: ['INT'],
          reaction:  { return: 'DEFAULT' }
        },
        {
          receiver:  Signal,
          selector:  :trap,
          arguments: ['TERM'],
          reaction:  { return: 'DEFAULT' }
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
          receiver:  Signal,
          selector:  :trap,
          arguments: ['INT', 'DEFAULT']
        },
        {
          receiver:  Signal,
          selector:  :trap,
          arguments: ['TERM', 'DEFAULT']
        },
        {
          receiver:  reporter,
          selector:  :report,
          arguments: [env_result]
        }
      ]
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

      it 'returns env result' do
        verify_events { expect(apply).to eql(env_result) }
      end
    end

    context 'when env has no mutations' do
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
    end

    context 'when interrupted before first result is returned' do
      let(:mutation) { instance_double(Mutant::Mutation) }

      let(:env) do
        instance_double(
          Mutant::Env,
          config:    config,
          mutations: [mutation]
        )
      end

      let(:raw_expectations) do
        [
          *super()[0..5],
          {
            receiver:  driver,
            selector:  :wait_timeout,
            arguments: [delay],
            reaction:  { exception: Interrupt.new }
          },
          {
            receiver:  Signal,
            selector:  :trap,
            arguments: ['INT', 'DEFAULT']
          },
          {
            receiver:  Signal,
            selector:  :trap,
            arguments: ['TERM', 'DEFAULT']
          },
          {
            receiver:  driver,
            selector:  :stop,
            reaction:  {
              return: instance_double(
                Mutant::Parallel::Status,
                payload: partial_env_result
              )
            }
          },
          {
            receiver:  reporter,
            selector:  :report,
            arguments: [partial_env_result]
          }
        ]
      end

      it 'reports the current sink status before re-raising' do
        verify_events { expect { apply }.to raise_error(Interrupt) }
      end
    end

    context 'when interrupted before the driver is assigned' do
      let(:mutation) { instance_double(Mutant::Mutation) }

      let(:env) do
        instance_double(
          Mutant::Env,
          config:    config,
          mutations: [mutation]
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
            receiver:  Mutant::Runner::Sink,
            selector:  :new,
            arguments: [env],
            reaction:  { return: sink }
          },
          {
            receiver:  Mutant::Parallel,
            selector:  :async,
            arguments: [parallel_config],
            reaction:  { exception: Interrupt.new }
          },
          {
            receiver:  sink,
            selector:  :status,
            reaction:  { return: partial_env_result }
          },
          {
            receiver:  reporter,
            selector:  :report,
            arguments: [partial_env_result]
          }
        ]
      end

      it 'reports sink status before re-raising' do
        verify_events { expect { apply }.to raise_error(Interrupt) }
      end
    end
  end

  describe '.call' do
    it 'freezes the runner before reading the final result' do
      runner = instance_double(described_class, result: env_result)

      expect(described_class).to receive(:build).with(env).ordered.and_return(runner)
      expect(runner).to receive(:freeze).ordered.and_return(runner)
      expect(runner).to receive(:result).ordered.and_return(env_result)

      expect(described_class.call(env)).to eql(env_result)
    end
  end

  describe '.build' do
    let(:mutation) { instance_double(Mutant::Mutation) }

    let(:env) do
      instance_double(
        Mutant::Env,
        config:    config,
        mutations: [mutation]
      )
    end

    it 'initializes and runs the runner before returning it' do
      expect(env).to receive(:method).with(:kill).and_return(processor)
      expect(Mutant::Runner::Sink).to receive(:new).with(env).and_return(sink)
      expect(Mutant::Parallel).to receive(:async).with(parallel_config).and_return(driver)
      expect(Signal).to receive(:trap).with('INT').and_return('DEFAULT')
      expect(Signal).to receive(:trap).with('TERM').and_return('DEFAULT')
      expect(driver).to receive(:wait_timeout).with(delay).and_return(status_b)
      expect(Signal).to receive(:trap).with('INT', 'DEFAULT')
      expect(Signal).to receive(:trap).with('TERM', 'DEFAULT')
      expect(reporter).to receive(:start).with(env)
      expect(reporter).to receive(:report).with(env_result)

      runner = described_class.send(:build, env)

      expect(runner).to be_instance_of(described_class)
      expect(runner.result).to eql(env_result)
    end
  end

  describe '#with_signal_handlers' do
    let(:runner) do
      described_class.allocate.tap do |object|
        object.send(:initialize, env)
      end
    end

    it 'raises Interrupt from both installed handlers and restores previous traps' do
      int_handler = term_handler = nil

      expect(Signal).to receive(:trap).with('INT') do |&block|
        int_handler = block
        'DEFAULT'
      end
      expect(Signal).to receive(:trap).with('TERM') do |&block|
        term_handler = block
        'IGNORE'
      end
      expect(Signal).to receive(:trap).with('INT', 'DEFAULT')
      expect(Signal).to receive(:trap).with('TERM', 'IGNORE')

      expect(
        runner.send(:with_signal_handlers) do
          expect { int_handler.call }.to raise_error(Interrupt)
          expect { term_handler.call }.to raise_error(Interrupt)
          :ok
        end
      ).to eql(:ok)
    end

    it 'does not restore handlers that were previously unset' do
      expect(Signal).to receive(:trap).with('INT').and_return(nil)
      expect(Signal).to receive(:trap).with('TERM').and_return(nil)
      expect(Signal).not_to receive(:trap).with('INT', nil)
      expect(Signal).not_to receive(:trap).with('TERM', nil)

      expect(runner.send(:with_signal_handlers) { :ok }).to eql(:ok)
    end

    it 'installs both handlers before yielding' do
      expect(Signal).to receive(:trap).with('INT').ordered.and_return('DEFAULT')
      expect(Signal).to receive(:trap).with('TERM').ordered.and_return('IGNORE')
      expect(Signal).to receive(:trap).with('INT', 'DEFAULT').ordered
      expect(Signal).to receive(:trap).with('TERM', 'IGNORE').ordered

      expect { runner.send(:with_signal_handlers) { :ok } }.not_to raise_error
    end
  end

  describe '#mutation_test_config' do
    let(:mutation) { instance_double(Mutant::Mutation) }

    let(:env) do
      instance_double(
        Mutant::Env,
        config:    config,
        mutations: [mutation]
      )
    end

    let(:runner) do
      described_class.allocate.tap do |object|
        object.send(:initialize, env)
      end
    end

    it 'builds the expected parallel config' do
      expect(env).to receive(:method).with(:kill).and_return(processor)
      expect(Mutant::Runner::Sink).to receive(:new).with(env).and_return(sink)

      expect(runner.send(:mutation_test_config)).to eql(parallel_config)
    end
  end

  describe '#run' do
    let(:mutation) { instance_double(Mutant::Mutation) }

    let(:env) do
      instance_double(
        Mutant::Env,
        config:    config,
        mutations: [mutation]
      )
    end

    let(:runner) do
      described_class.allocate.tap do |object|
        object.send(:initialize, env)
      end
    end

    it 'sets the final result after reporting it' do
      expect(env).to receive(:method).with(:kill).and_return(processor)
      expect(Mutant::Runner::Sink).to receive(:new).with(env).and_return(sink)
      expect(Mutant::Parallel).to receive(:async).with(parallel_config).and_return(driver)
      expect(Signal).to receive(:trap).with('INT').and_return('DEFAULT')
      expect(Signal).to receive(:trap).with('TERM').and_return('DEFAULT')
      expect(driver).to receive(:wait_timeout).with(delay).and_return(status_b)
      expect(Signal).to receive(:trap).with('INT', 'DEFAULT')
      expect(Signal).to receive(:trap).with('TERM', 'DEFAULT')

      expect(reporter).to receive(:start).with(env).ordered
      expect(reporter).to receive(:report).with(env_result).ordered do
        expect(runner.instance_variable_defined?(:@result)).to be(false)
      end

      expect(runner.send(:run).result).to eql(env_result)
    end

    it 'does not ask the sink for a status when the driver returns a final result' do
      expect(env).to receive(:method).with(:kill).and_return(processor)
      expect(Mutant::Runner::Sink).to receive(:new).with(env).and_return(sink)
      expect(Mutant::Parallel).to receive(:async).with(parallel_config).and_return(driver)
      expect(Signal).to receive(:trap).with('INT').and_return('DEFAULT')
      expect(Signal).to receive(:trap).with('TERM').and_return('DEFAULT')
      expect(driver).to receive(:wait_timeout).with(delay).and_return(status_b)
      expect(Signal).to receive(:trap).with('INT', 'DEFAULT')
      expect(Signal).to receive(:trap).with('TERM', 'DEFAULT')
      expect(reporter).to receive(:start).with(env)
      expect(reporter).to receive(:report).with(env_result)
      expect(sink).not_to receive(:status)

      runner.send(:run)
    end

    it 'returns self after storing the final result' do
      expect(env).to receive(:method).with(:kill).and_return(processor).once
      expect(Mutant::Runner::Sink).to receive(:new).with(env).and_return(sink).once
      expect(Mutant::Parallel).to receive(:async).with(parallel_config).and_return(driver).once
      expect(Signal).to receive(:trap).with('INT').and_return('DEFAULT').once
      expect(Signal).to receive(:trap).with('TERM').and_return('DEFAULT').once
      expect(driver).to receive(:wait_timeout).with(delay).and_return(status_b).once
      expect(Signal).to receive(:trap).with('INT', 'DEFAULT').once
      expect(Signal).to receive(:trap).with('TERM', 'DEFAULT').once
      expect(reporter).to receive(:start).with(env).once
      expect(reporter).to receive(:report).with(env_result).once

      expect(runner.send(:run)).to equal(runner)
      expect(runner.result).to eql(env_result)
    end

    it 'warns via reporter when result writing fails' do
      expect(env).to receive(:method).with(:kill).and_return(processor)
      expect(Mutant::Runner::Sink).to receive(:new).with(env).and_return(sink)
      expect(Mutant::Parallel).to receive(:async).with(parallel_config).and_return(driver)
      expect(Signal).to receive(:trap).with('INT').and_return('DEFAULT')
      expect(Signal).to receive(:trap).with('TERM').and_return('DEFAULT')
      expect(driver).to receive(:wait_timeout).with(delay).and_return(status_b)
      expect(Signal).to receive(:trap).with('INT', 'DEFAULT')
      expect(Signal).to receive(:trap).with('TERM', 'DEFAULT')
      expect(reporter).to receive(:start).with(env)
      expect(reporter).to receive(:report).with(env_result)

      failing_io = instance_double(Mutant::Result::Env::IO)
      allow(Mutant::Result::Env::IO).to receive(:new).with(env_result).and_return(failing_io)

      custom_error = Class.new(StandardError) do
        def message
          'the-message'
        end

        def to_s
          'the-to_s'
        end
      end
      allow(failing_io).to receive(:call).and_raise(custom_error.new)

      expected_message = 'Failed to write results: the-message'
      expect(reporter).to receive(:warn).with(expected_message)

      result = runner.send(:run)
      expect(result.result).to eql(env_result)
    end

    it 'invokes Result::Env::IO to write results on success' do
      expect(env).to receive(:method).with(:kill).and_return(processor)
      expect(Mutant::Runner::Sink).to receive(:new).with(env).and_return(sink)
      expect(Mutant::Parallel).to receive(:async).with(parallel_config).and_return(driver)
      expect(Signal).to receive(:trap).with('INT').and_return('DEFAULT')
      expect(Signal).to receive(:trap).with('TERM').and_return('DEFAULT')
      expect(driver).to receive(:wait_timeout).with(delay).and_return(status_b)
      expect(Signal).to receive(:trap).with('INT', 'DEFAULT')
      expect(Signal).to receive(:trap).with('TERM', 'DEFAULT')
      expect(reporter).to receive(:start).with(env)
      expect(reporter).to receive(:report).with(env_result)

      success_io = instance_double(Mutant::Result::Env::IO)
      expect(Mutant::Result::Env::IO).to receive(:new).with(env_result).and_return(success_io)
      expect(success_io).to receive(:call)

      runner.send(:run)
    end
  end
end

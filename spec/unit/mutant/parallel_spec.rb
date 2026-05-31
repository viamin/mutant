# frozen_string_literal: true

RSpec.describe Mutant::Parallel do
  describe '.worker' do
    let(:condition_variable) { class_double(ConditionVariable)          }
    let(:jobs)               { 2                                        }
    let(:mutex)              { class_double(Mutex)                      }
    let(:processor)          { instance_double(Proc)                    }
    let(:sink)               { instance_double(described_class::Sink)   }
    let(:source)             { instance_double(described_class::Source) }
    let(:thread)             { class_double(Thread)                     }
    let(:var_active_jobs)    { instance_double(Mutant::Variable::IVar)  }
    let(:var_final)          { instance_double(Mutant::Variable::IVar)  }
    let(:var_running)        { instance_double(Mutant::Variable::MVar)  }
    let(:var_sink)           { instance_double(Mutant::Variable::IVar)  }
    let(:var_source)         { instance_double(Mutant::Variable::MVar)  }
    let(:worker)             { instance_double(Mutant::Parallel::Worker) }

    let(:config) do
      Mutant::Parallel::Config.new(
        condition_variable: condition_variable,
        jobs:               jobs,
        mutex:              mutex,
        processor:          processor,
        sink:               sink,
        source:             source,
        thread:             thread
      )
    end

    let(:shared_state) do
      {
        var_active_jobs: var_active_jobs,
        var_final:       var_final,
        var_sink:        var_sink,
        var_source:      var_source
      }
    end

    it 'returns a worker configured with a running-job mvar' do
      expect(described_class).to receive(:shared)
        .with(Mutant::Variable::MVar, config, value: jobs)
        .and_return(var_running)
      expect(Mutant::Parallel::Worker).to receive(:new).with(
        processor:       processor,
        var_active_jobs: var_active_jobs,
        var_final:       var_final,
        var_running:     var_running,
        var_sink:        var_sink,
        var_source:      var_source
      ).and_return(worker)

      expect(described_class.worker(config, **shared_state)).to eql(worker)
    end
  end

  describe '.async' do
    def apply
      described_class.async(config)
    end

    let(:condition_variable) { class_double(ConditionVariable)          }
    let(:jobs)               { 2                                        }
    let(:mutex)              { class_double(Mutex)                      }
    let(:processor)          { instance_double(Proc)                    }
    let(:sink)               { instance_double(described_class::Sink)   }
    let(:source)             { instance_double(described_class::Source) }
    let(:thread)             { class_double(Thread)                     }
    let(:thread_a)           { instance_double(Thread)                  }
    let(:thread_b)           { instance_double(Thread)                  }
    let(:worker)             { -> {}                                    }

    let(:config) do
      Mutant::Parallel::Config.new(
        condition_variable: condition_variable,
        jobs:               jobs,
        mutex:              mutex,
        processor:          processor,
        sink:               sink,
        source:             source,
        thread:             thread
      )
    end

    let(:var_active_jobs) do
      instance_double(Mutant::Variable::IVar, 'active jobs')
    end

    let(:var_final) do
      instance_double(Mutant::Variable::IVar, 'final')
    end

    let(:var_running) do
      instance_double(Mutant::Variable::MVar, 'running')
    end

    let(:var_sink) do
      instance_double(Mutant::Variable::IVar, 'sink')
    end

    let(:var_source) do
      instance_double(Mutant::Variable::MVar, 'source')
    end

    def ivar(value, **attributes)
      {
        receiver:  Mutant::Variable::IVar,
        selector:  :new,
        arguments: [
          {
            condition_variable: condition_variable,
            mutex:              mutex,
            **attributes
          }
        ],
        reaction:  { return: value }
      }
    end

    def mvar(value, **attributes)
      ivar(value, **attributes).merge(receiver: Mutant::Variable::MVar)
    end

    let(:raw_expectations) do
      [
        ivar(var_active_jobs, value: Set.new),
        ivar(var_final),
        ivar(var_sink, value: sink),
        mvar(var_source, value: source),
        mvar(var_running, value: 2),
        {
          receiver:  Mutant::Parallel::Worker,
          selector:  :new,
          arguments: [
            {
              processor:       processor,
              var_active_jobs: var_active_jobs,
              var_final:       var_final,
              var_running:     var_running,
              var_sink:        var_sink,
              var_source:      var_source
            }
          ],
          reaction:  { return: worker }
        },
        {
          receiver: thread,
          selector: :new,
          reaction: { yields: [], return: thread_a }
        },
        {
          receiver: thread,
          selector: :new,
          reaction: { yields: [], return: thread_b }
        }
      ]
    end

    it 'returns driver' do
      verify_events do
        expect(apply).to eql(
          described_class::Driver.new(
            threads:         [thread_a, thread_b],
            var_active_jobs: var_active_jobs,
            var_final:       var_final,
            var_sink:        var_sink,
            var_source:      var_source
          )
        )
      end
    end
  end
end

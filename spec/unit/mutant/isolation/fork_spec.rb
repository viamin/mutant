# frozen_string_literal: true

# The fork isolation is all about managing a series of systemcalls with proper error handling
#
# So creating a unit spec for this is challenging. Especially under mutation testing.
# Hence we even have to implement our own message expectation mechanism, as rspec build in
# expectations are not able to correctly specify a sequence of expectations where a specific
# message is send twice.
#
# Also our replacement for rspec-expectations used here allows easier deduplication.
RSpec.describe Mutant::Isolation::Fork do
  let(:block_return)      { instance_double(Object, :block_return)      }
  let(:block_return_blob) { instance_double(String, :block_return_blob) }
  let(:devnull)           { instance_double(Proc, :devnull)             }
  let(:io)                { class_double(IO)                            }
  let(:isolated_block)    { -> { block_return }                         }
  let(:marshal)           { class_double(Marshal)                       }
  let(:process)           { class_double(Process)                       }
  let(:pid)               { class_double(0.class)                       }
  let(:reader)            { instance_double(IO, :reader)                }
  let(:stderr)            { instance_double(IO, :stderr)                }
  let(:stdout)            { instance_double(IO, :stdout)                }
  let(:writer)            { instance_double(IO, :writer)                }
  let(:nullio)            { instance_double(IO, :nullio)                }

  let(:status_success) do
    instance_double(Process::Status, success?: true)
  end

  let(:fork_success) do
    {
      receiver: process,
      selector: :fork,
      reaction: {
        yields: [],
        return: pid
      }
    }
  end

  let(:child_wait) do
    {
      receiver:  process,
      selector:  :wait2,
      arguments: [pid],
      reaction:  {
        return: [pid, status_success]
      }
    }
  end

  let(:writer_close) do
    {
      receiver: writer,
      selector: :close
    }
  end

  let(:read_child_result_blob) do
    {
      receiver:  reader,
      selector:  :read,
      reaction:  {
        return: block_return_blob
      }
    }
  end

  let(:marshal_load_success) do
    {
      receiver:  marshal,
      selector:  :load,
      arguments: [block_return_blob],
      reaction:  {
        return: block_return
      }
    }
  end

  let(:killfork) do
    [
      # Inside the killfork
      {
        receiver: reader,
        selector: :close
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
        receiver: devnull,
        selector: :call,
        reaction: {
          yields: [nullio]
        }
      },
      {
        receiver:  stderr,
        selector:  :reopen,
        arguments: [nullio]
      },
      {
        receiver:  stdout,
        selector:  :reopen,
        arguments: [nullio]
      },
      {
        receiver:  marshal,
        selector:  :dump,
        arguments: [block_return],
        reaction:  {
          return: block_return_blob
        }
      },
      {
        receiver:  writer,
        selector:  :write,
        arguments: [block_return_blob]
      },
      writer_close
    ]
  end

  describe '#call' do
    let(:object) do
      described_class.new(
        devnull: devnull,
        io:      io,
        marshal: marshal,
        process: process,
        stderr:  stderr,
        stdout:  stdout
      )
    end

    subject { object.call(&isolated_block) }

    let(:prefork_expectations) do
      [
        {
          receiver:  io,
          selector:  :pipe,
          arguments: [{ binmode: true }],
          reaction:  {
            yields: [[reader, writer]]
          }
        }
      ]
    end

    context 'when no IO operation fails' do
      let(:expectations) do
        [
          *prefork_expectations,
          fork_success,
          *killfork,
          writer_close,
          read_child_result_blob,
          marshal_load_success,
          child_wait
        ].map(&XSpec::MessageExpectation.method(:parse))
      end

      specify do
        XSpec::ExpectationVerifier.verify(self, expectations) do
          expect(subject).to eql(Mutant::Isolation::Result::Success.new(block_return))
        end
      end
    end

    context 'when the isolated block raises an exception' do
      let(:exception) do
        RuntimeError.new('boom').tap do |error|
          error.set_backtrace(%w[line-a line-b])
        end
      end
      let(:exception_result) do
        Mutant::Isolation::Result::Exception.new(
          Mutant::Isolation::Result::SerializedException.new(
            exception.backtrace || Mutant::EMPTY_ARRAY,
            exception.class.name,
            exception.inspect
          )
        )
      end
      let(:exception_result_blob) { instance_double(String, :exception_result_blob) }
      let(:isolated_block) { -> { raise exception } }

      let(:expectations) do
        [
          *prefork_expectations,
          fork_success,
          {
            receiver: reader,
            selector: :close
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
            receiver: devnull,
            selector: :call,
            reaction: {
              yields: [nullio]
            }
          },
          {
            receiver:  stderr,
            selector:  :reopen,
            arguments: [nullio]
          },
          {
            receiver:  stdout,
            selector:  :reopen,
            arguments: [nullio]
          },
          {
            receiver:  marshal,
            selector:  :dump,
            arguments: [exception_result],
            reaction:  {
              return: exception_result_blob
            }
          },
          {
            receiver:  writer,
            selector:  :write,
            arguments: [exception_result_blob]
          },
          writer_close,
          writer_close,
          {
            receiver:  reader,
            selector:  :read,
            reaction:  {
              return: exception_result_blob
            }
          },
          {
            receiver:  marshal,
            selector:  :load,
            arguments: [exception_result_blob],
            reaction:  {
              return: exception_result
            }
          },
          child_wait
        ].map(&XSpec::MessageExpectation.method(:parse))
      end

      specify do
        XSpec::ExpectationVerifier.verify(self, expectations) do
          expect(subject).to eql(exception_result)
        end
      end
    end

    context 'when the isolated block exits' do
      let(:exception) do
        SystemExit.new(1).tap do |error|
          error.set_backtrace(%w[line-a line-b])
        end
      end
      let(:exception_result) do
        Mutant::Isolation::Result::Exception.new(
          Mutant::Isolation::Result::SerializedException.new(
            exception.backtrace || Mutant::EMPTY_ARRAY,
            exception.class.name,
            exception.inspect
          )
        )
      end
      let(:exception_result_blob) { instance_double(String, :exception_result_blob) }
      let(:isolated_block) { -> { raise exception } }

      let(:expectations) do
        [
          *prefork_expectations,
          fork_success,
          {
            receiver: reader,
            selector: :close
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
            receiver: devnull,
            selector: :call,
            reaction: {
              yields: [nullio]
            }
          },
          {
            receiver:  stderr,
            selector:  :reopen,
            arguments: [nullio]
          },
          {
            receiver:  stdout,
            selector:  :reopen,
            arguments: [nullio]
          },
          {
            receiver:  marshal,
            selector:  :dump,
            arguments: [exception_result],
            reaction:  {
              return: exception_result_blob
            }
          },
          {
            receiver:  writer,
            selector:  :write,
            arguments: [exception_result_blob]
          },
          writer_close,
          writer_close,
          {
            receiver:  reader,
            selector:  :read,
            reaction:  {
              return: exception_result_blob
            }
          },
          {
            receiver:  marshal,
            selector:  :load,
            arguments: [exception_result_blob],
            reaction:  {
              return: exception_result
            }
          },
          child_wait
        ].map(&XSpec::MessageExpectation.method(:parse))
      end

      specify do
        XSpec::ExpectationVerifier.verify(self, expectations) do
          expect(subject).to eql(exception_result)
        end
      end
    end

    context 'when the isolated block raises an exception that cannot be marshaled' do
      let(:exception_class) do
        Class.new(StandardError) do
          def backtrace
            nil
          end

          def initialize
            @io = $stdout
            super('boom')
          end
        end
      end

      let(:exception) { exception_class.new }
      let(:serialized_exception) do
        Mutant::Isolation::Result::SerializedException.new(
          exception.backtrace || Mutant::EMPTY_ARRAY,
          exception.class.name,
          exception.inspect
        )
      end
      let(:exception_result) { Mutant::Isolation::Result::Exception.new(serialized_exception) }
      let(:exception_result_blob) { instance_double(String, :exception_result_blob) }
      let(:isolated_block) { -> { raise exception } }

      let(:expectations) do
        [
          *prefork_expectations,
          fork_success,
          {
            receiver: reader,
            selector: :close
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
            receiver: devnull,
            selector: :call,
            reaction: {
              yields: [nullio]
            }
          },
          {
            receiver:  stderr,
            selector:  :reopen,
            arguments: [nullio]
          },
          {
            receiver:  stdout,
            selector:  :reopen,
            arguments: [nullio]
          },
          {
            receiver:  marshal,
            selector:  :dump,
            arguments: [exception_result],
            reaction:  {
              return: exception_result_blob
            }
          },
          {
            receiver:  writer,
            selector:  :write,
            arguments: [exception_result_blob]
          },
          writer_close,
          writer_close,
          {
            receiver:  reader,
            selector:  :read,
            reaction:  {
              return: exception_result_blob
            }
          },
          {
            receiver:  marshal,
            selector:  :load,
            arguments: [exception_result_blob],
            reaction:  {
              return: exception_result
            }
          },
          child_wait
        ].map(&XSpec::MessageExpectation.method(:parse))
      end

      specify do
        XSpec::ExpectationVerifier.verify(self, expectations) do
          expect(subject).to eql(exception_result)
        end
      end
    end

    context 'when expected exception was raised when reading from child' do
      [ArgumentError, EOFError].each do |exception_class|
        context "on #{exception_class}" do
          let(:exception) { exception_class.new }

          let(:expectations) do
            [
              *prefork_expectations,
              fork_success,
              *killfork,
              {
                receiver: writer,
                selector: :close,
                reaction: {
                  exception: exception
                }
              },
              child_wait
            ].map(&XSpec::MessageExpectation.method(:parse))
          end

          specify do
            XSpec::ExpectationVerifier.verify(self, expectations) do
              expect(subject).to eql(Mutant::Isolation::Result::Exception.new(exception))
            end
          end
        end
      end
    end

    context 'when fork fails' do
      let(:result_class) { described_class::ForkError }

      let(:expectations) do
        [
          *prefork_expectations,
          {
            receiver: process,
            selector: :fork,
            reaction: {
              return: nil
            }
          }
        ].map(&XSpec::MessageExpectation.method(:parse))
      end

      specify do
        XSpec::ExpectationVerifier.verify(self, expectations) do
          expect(subject).to eql(result_class.new)
        end
      end
    end

    context 'when child exits nonzero' do
      let(:status_error) do
        instance_double(Process::Status, success?: false)
      end

      let(:expected_result) do
        Mutant::Isolation::Result::ErrorChain.new(
          described_class::ChildError.new(status_error),
          Mutant::Isolation::Result::Success.new(block_return)
        )
      end

      let(:expectations) do
        [
          *prefork_expectations,
          fork_success,
          *killfork,
          writer_close,
          read_child_result_blob,
          marshal_load_success,
          {
            receiver:  process,
            selector:  :wait2,
            arguments: [pid],
            reaction:  {
              return: [pid, status_error]
            }
          }
        ].map(&XSpec::MessageExpectation.method(:parse))
      end

      specify do
        XSpec::ExpectationVerifier.verify(self, expectations) do
          expect(subject).to eql(expected_result)
        end
      end
    end
  end
end

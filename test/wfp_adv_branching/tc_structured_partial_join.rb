require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../TestWorkflow')

# only variant Cancelling Structured Partial Join is implemented, but that's the coolest one 8)
class TestWFPCancellingStructuredPartialJoin < Test::Unit::TestCase
  include TestMixin

  def test_cancelling_structured_partial_join
    @wf.description do
      parallel :wait => 3 do
        parallel_branch do
          call :a_1, :endpoint1
        end
        parallel_branch do
          call :a_2, :endpoint1, parameters: { :call => Proc.new{sleep 0.2} }
        end
        parallel_branch do
          call :a_3, :endpoint1
        end
        parallel_branch do
          call :a_4, :endpoint1, parameters: { :call => Proc.new{sleep 0.6} }
        end
        parallel_branch do
          call :a_5, :endpoint1
        end
      end
      call :a_6, :endpoint1, parameters: { :call => Proc.new{sleep 0.2} }
    end
    @wf.start.join
    wf_assert("CALL a_1:")
    wf_assert("CALL a_2:")
    wf_assert("CALL a_3:")
    wf_assert("CALL a_4:")
    wf_assert("CALL a_5:")
    wf_assert("DONE a_1")
    wf_assert("DONE a_3")
    wf_assert("DONE a_5")
    wf_assert("CALL a_6:")
    wf_assert("DONE a_6")
  end
end

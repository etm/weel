require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../TestWorkflow')

# implemented as a combination of the Cancelling Structured Partial Join and the Exclusive Choice Pattern
class TestWFPDeferredChoice < Test::Unit::TestCase
  include TestMixin

  def test_sequence
    @wf.description do
      parallel :p1, :wait=>1 do
        parallel_branch :p1_1 do
          call :a1_1, :endpoint1, parameters: { :call => Proc.new{sleep 0.5} }, finalize: 'data.choice = 1'
          Thread.pass
        end
        parallel_branch :p1_2 do
          call :a1_2, :endpoint1, parameters: { :call => Proc.new{sleep 1.0} }, finalize: 'data.choice = 2'
        end
      end
      choose :c1 do
        alternative(:c1_1, 'data.choice == 1') do
          call :a2_1, :endpoint1
        end
        alternative(:c1_2, 'data.choice == 2') do
          call :a2_2, :endpoint1
        end
      end
    end
    @wf.start.join
    wf_assert('CALL a1_1')
    wf_assert('DONE a1_1')
    wf_assert('MANIPULATE a1_1')
    wf_sassert('Sa1_2NLNa1_2Da1_2Ca2_1Da2_1|finished|')
    data = @wf.data
    assert(data[:choice] == 1, "data[:choice] has not the correct value [#{data[:x]}]")
  end
end

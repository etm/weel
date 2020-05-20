require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../TestWorkflow')

class TestWorkflowControl < Test::Unit::TestCase
  include TestMixin

  def test_runthrough
    @wf.start.join
    wf_assert("DONE a1_1")
    wf_assert("CALL a2_1_1:")
    wf_assert("CALL a2_2_1:")
    wf_assert("DONE a2_1_1")
    wf_assert("DONE a2_2_1")
    wf_assert("DONE a3")
    wf_assert("DONE a4a")
    assert(@wf.state == :finished, "Stopped workflow has wrong state, #{@wf.state} instead of :stopped")
    assert(@wf.positions.is_a?(Array) && @wf.positions.empty?, "@wf.positions has wrong type, should be an empty array, it is: #{@wf.positions.inspect}")
    assert(@wf.data[:x] == "begin_Handler_Dummy_Result_end", "Ending environment not correct, see result=#{@wf.data[:x].inspect}")
  end

  # def test_stop
  #   @wf.description do
  #     call :a_test_1_1, :endpoint1
  #     call :a_test_1_2, :endpoint1, parameters: { :call => Proc.new{ sleep 0.5 } }
  #     call :a_test_1_3, :endpoint1
  #   end
  #   @wf.search WEEL::Position.new(:a_test_1_1, :at)
  #   wf = @wf.start
  #   sleep(0.2)
  #   @wf.stop.join
  #   wf.join
  #   wf_assert("DONE a_test_1_1")
  #   wf_assert("STOPPED a_test_1_2")
  #   wf_assert("DONE a_test_1_2",false)
  #   wf_assert("CALL a_test_1_2:")
  #   assert(@wf.state == :stopped, "Stopped workflow has wrong state, #{@wf.state} instead of :stopped")
  #   assert(@wf.positions.is_a?(Array), "@wf.positions has wrong type, should be an array, it is: #{@wf.positions.inspect}")
  #   assert(@wf.positions[0].position == :a_test_1_2, "Stop-position has wrong value: #{@wf.positions[0].position} instead of :a_test_2_1")
  #   assert(@wf.positions[0].detail == :at, "Stop-Position is not :at")
  # end
  # def test_continue
  #   @wf.description do
  #     call :a_test_1_1, :endpoint1
  #     call :a_test_1_2, :endpoint1, parameters: { :call =>  Proc.new{ sleep 0.5 } }
  #     call :a_test_1_3, :endpoint1
  #   end
  #   @wf.start
  #   sleep(0.2)
  #   @wf.stop.join

  #   @wf.search @wf.positions

  #   @wf.start.join
  #   wf_sassert('|running|Ca_test_1_1Da_test_1_1Ca_test_1_2|stopping|Sa_test_1_2|stopped||running|Ca_test_1_2Da_test_1_2Ca_test_1_3Da_test_1_3|finished|')
  # end

  # def test_continue_after
  #   @wf.description do
  #     call :c_test_1_1, :endpoint1
  #     call :c_test_1_2, :endpoint1
  #     call :c_test_1_3, :endpoint1
  #   end
  #   @wf.search [WEEL::Position.new(:c_test_1_1, :after)]
  #   @wf.start.join

  #   wf_sassert('|running|Cc_test_1_2Dc_test_1_2Cc_test_1_3Dc_test_1_3|finished|')
  # end
end

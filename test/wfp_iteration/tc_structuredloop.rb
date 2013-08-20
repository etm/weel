require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../TestWorkflow')

# implemented as a combination of the Cancelling Structured Partial Join and the Exclusive Choice Pattern
class TestWFPInterleavedParallelRouting < Test::Unit::TestCase
  include TestMixin

  def test_loop
    @wf.description do
      manipulate :a1 do
        data.x = 0
      end
      loop pre_test{data.x < 3} do
        call :a2, :endpoint1 do
          data.x += 1
        end
      end
      call :a3, :endpoint1
    end
    @wf.start.join
    wf_sassert('|running|Ma1Da1Ca2Ma2Da2Ca2Ma2Da2Ca2Ma2Da2Ca3Da3|finished|');
    data = @wf.data
    assert(data[:x] == 3, "data[:x] has not the correct value [#{data[:x]}]")
  end
  def test_loop_search
    @wf.description do
      manipulate :a1 do
        data.x = 0
      end
      loop pre_test{data.x < 3} do
        call :a2_1, :endpoint1
        manipulate :a2_2 do
          data.x += 1
        end
      end
      call :a3, :endpoint1
    end
    @wf.search WEEL::Position.new(:a2_2, :at)
    @wf.data :x => 2
    @wf.start.join
    wf_sassert('|running|Ma2_2Da2_2Ca3Da3|finished|');
    data = @wf.data
    assert(data[:x] == 3, "data[:x] has not the correct value [#{data[:x]}]")
  end
  def test_loop_jump_over
    @wf.description do
      manipulate :a1 do
        data.x = 0
      end
      loop pre_test{data.x < 3} do
        call :a2_1, :endpoint1
        manipulate :a2_2 do
          data.x += 1
        end
      end
      call :a3, :endpoint1
    end
    @wf.search WEEL::Position.new(:a3, :at)
    @wf.data :x => 0
    @wf.start.join
    wf_sassert('|running|Ca3Da3|finished|');
    data = @wf.data
    assert(data[:x] == 0, "data[:x] has not the correct value [#{data[:x]}]")
  end
end

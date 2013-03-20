require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../../lib/weel')
require File.expand_path(::File.dirname(__FILE__) + '/../SimHandlerWrapper')

class TestSimLoop < Test::Unit::TestCase

  class SimWorkflowLoop < WEEL
    handlerwrapper SimHandlerWrapper
    
    endpoint :ep1 => "data.at"

    data :hotels  => []
    data :airline => ''
    data :costs   => 0
    data :persons => 3

    control flow do
      loop pre_test{data.persons > 0} do
        activity :a1, :call, :endpoint1 do
          data.hotels << 'Rathaus'
          data.costs += 200
        end
        activity :a2, :call, :endpoint1 do
          data.hotels << 'Rathaus'
          data.costs += 200
        end
      end
    end
  end

  def test_loop
    wf = SimWorkflowLoop.new
    wf.sim.join

    pp $trace
  end
end

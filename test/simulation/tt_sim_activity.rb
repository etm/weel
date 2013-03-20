require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../../lib/weel')
require File.expand_path(::File.dirname(__FILE__) + '/../SimHandlerWrapper')

class TestSimActivities < Test::Unit::TestCase

  class SimWorkflowActivities < WEEL
    handlerwrapper SimHandlerWrapper
    
    endpoint :ep1 => "data.at"

    data :hotels  => []
    data :airline => ''
    data :costs   => 0
    data :persons => 3

    control flow do
      activity :a1, :call, :endpoint1 do
        data.airline = 'Aeroflot'
        data.costs  += 101
        status.update 1, 'Hotel'
      end
      activity :a2, :call, :endpoint1 do
        data.airline = 'Aeroflot'
        data.costs  += 101
        status.update 1, 'Hotel'
      end
    end  
  end  

  def test_it
    wf = SimWorkflowActivities.new
    wf.sim.join

    pp $trace
  end
end

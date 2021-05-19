require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../../lib/weel')
require File.expand_path(::File.dirname(__FILE__) + '/../SimConnectionWrapper')

class TestSimActivities < Test::Unit::TestCase

  class SimWorkflowActivities < WEEL
    connectionwrapper SimConnectionWrapper

    endpoint :ep1 => "data.at"

    data :hotels  => []
    data :airline => ''
    data :costs   => 0
    data :persons => 3

    control flow do
      call :a1, :endpoint1 do
        data.airline = 'Aeroflot'
        data.costs  += 101
        status.update 1, 'Hotel'
      end
      call :a2, :endpoint1 do
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

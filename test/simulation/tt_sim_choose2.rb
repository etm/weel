require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../../lib/weel')
require File.expand_path(::File.dirname(__FILE__) + '/../SimConnectionWrapper')

class TestSimChoose2 < Test::Unit::TestCase

  class SimWorkflowChoose2 < WEEL
    connectionwrapper SimConnectionWrapper

    endpoint :ep1 => "data.at"

    data :hotels  => []
    data :airline => ''
    data :costs   => 0
    data :persons => 3

    control flow do
      choose :inclusive do
        alternative data.costs > 400 do
          call :a1, :endpoint1
        end
        alternative data.costs > 400 do
          call :a2, :endpoint1
        end
        otherwise do
          call :a2, :endpoint1
        end
      end
    end
  end

  def test_it
    wf = SimWorkflowChoose2.new
    wf.sim.join

    pp $trace
  end
end

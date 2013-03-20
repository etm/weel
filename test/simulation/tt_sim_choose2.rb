require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../../lib/weel')
require File.expand_path(::File.dirname(__FILE__) + '/../SimHandlerWrapper')

class TestSimChoose2 < Test::Unit::TestCase

  class SimWorkflowChoose2 < WEEL
    handlerwrapper SimHandlerWrapper
    
    endpoint :ep1 => "data.at"

    data :hotels  => []
    data :airline => ''
    data :costs   => 0
    data :persons => 3

    control flow do
      choose :inclusive do
        alternative data.costs > 400 do
          activity :a1, :call, :endpoint1
        end
        alternative data.costs > 400 do
          activity :a2, :call, :endpoint1
        end
        otherwise do
          activity :a2, :call, :endpoint1
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

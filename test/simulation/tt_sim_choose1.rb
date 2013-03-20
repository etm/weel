require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../../lib/weel')
require File.expand_path(::File.dirname(__FILE__) + '/../SimHandlerWrapper')

class TestSimChoose1 < Test::Unit::TestCase

  class SimWorkflowChoose1 < WEEL
    handlerwrapper SimHandlerWrapper
    
    endpoint :ep1 => "data.at"

    data :hotels  => []
    data :airline => ''
    data :costs   => 0
    data :persons => 3

    control flow do
      activity :a0, :call, :endpoint1
      choose :exclusive do
        alternative data.costs > 400 do
          activity :a11, :call, :endpoint1
          activity :a12, :call, :endpoint1
        end
        alternative data.costs > 400 do
          activity :a21, :call, :endpoint1
          activity :a22, :call, :endpoint1
        end
        otherwise do
          activity :a3, :call, :endpoint1
        end
      end
    end
  end  

  def setup
    $trace = Trace.new
  end

  def teardown
    $trace.generate_list
  end

  def test_it
    wf = SimWorkflowChoose1.new
    wf.sim.join
  end
end

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
      call :a0, :endpoint1
      choose :exclusive do
        alternative data.costs > 400 do
          call :a11, :endpoint1
          call :a12, :endpoint1
        end
        alternative data.costs > 400 do
          call :a21, :endpoint1
          call :a22, :endpoint1
        end
        otherwise do
          call :a3, :endpoint1
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

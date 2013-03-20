require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../../lib/weel')
require File.expand_path(::File.dirname(__FILE__) + '/../SimHandlerWrapper')

class TestSimParallel < Test::Unit::TestCase


  class SimWorkflowParallel < WEEL
    handlerwrapper SimHandlerWrapper
    
    endpoint :ep1 => "data.at"

    data :hotels  => []
    data :airline => ''
    data :costs   => 0
    data :persons => 3

    control flow do
      parallel do
        parallel_branch do
          activity :a1, :call, :endpoint1 do
            data.hotels << 'Rathaus'
            data.costs += 200
          end
        end
        loop pre_test{data.persons > 0} do
          parallel_branch data.persons do |p|
            activity :a2, :call, :endpoint1 do
              data.hotels << 'Rathaus'
              data.costs += 200
            end
            activity :a3, :call, :endpoint1 do
              data.hotels << 'Rathaus'
              data.costs += 200
            end
          end
          activity :a4, :manipulate do
            data.persons -= 1
          end
        end
      end
    end
  end

  def test_parallel
    wf = SimWorkflowParallel.new
    wf.sim.join

    pp $trace
  end
end

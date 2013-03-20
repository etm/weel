require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../../lib/weel')
require File.expand_path(::File.dirname(__FILE__) + '/../SimHandlerWrapper')

class TestSimParallelChoose < Test::Unit::TestCase

  class SimWorkflowParallelChoose < WEEL
    handlerwrapper SimHandlerWrapper
    
    endpoint :ep1 => "data.at"

    data :hotels  => []
    data :airline => ''
    data :costs   => 0
    data :persons => 3

    control flow do
      parallel do
        loop pre_test{data.persons > 0} do
          choose do
            alternative data.costs > 400 do 
              parallel_branch data.persons do |p|
                activity :a2, :call, :endpoint1 do
                  data.hotels << 'Rathaus'
                  data.costs += 200
                end
              end
            end  
            otherwise do
              parallel_branch data.persons do |p|
                activity :a2, :call, :endpoint1 do
                  data.hotels << 'Rathaus'
                  data.costs += 200
                end
              end
            end
          end
          activity :a3, :manipulate do
            data.persons -= 1
          end
        end
      end
    end
  end

  def test_parallel_choose
    wf = SimWorkflowParallelChoose.new
    wf.sim.join

    pp $trace
  end
end

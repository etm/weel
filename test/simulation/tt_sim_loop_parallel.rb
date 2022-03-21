require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../../lib/weel')
require File.expand_path(::File.dirname(__FILE__) + '/../SimConnectionWrapper')

class TestSimParallel < Test::Unit::TestCase


  class SimWorkflowParallel < WEEL
    connectionwrapper SimConnectionWrapper

    endpoint :ep1 => "data.at"

    data :hotels  => []
    data :airline => ''
    data :costs   => 0
    data :persons => 3

    control flow do
      parallel do
        parallel_branch do
          call :a1, :endpoint1 do
            data.hotels << 'Rathaus'
            data.costs += 200
          end
        end
        loop pre_test{data.persons > 0} do
          parallel_branch data.persons do |p|
            call :a2, :endpoint1 do
              data.hotels << 'Rathaus'
              data.costs += 200
            end
            call :a3, :endpoint1 do
              data.hotels << 'Rathaus'
              data.costs += 200
            end
          end
          manipulate :a4 do
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

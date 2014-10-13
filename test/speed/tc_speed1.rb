require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../TestWorkflow')

class TestSpeed1 < Test::Unit::TestCase
  include TestMixin

  def test_speed1
    1.upto(10000) do
      wf = TestWorkflow.new
      wf.description do
        choose do
          alternative true do
            call :a_1, :endpoint1
          end
          alternative false do
            call :a_2, :endpoint1
          end
          otherwise do
            call :a_3, :endpoint1
          end
        end
      end
      wf.start.join
    end  
  end

end

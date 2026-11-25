require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../TestWorkflow')

class TestSpeed1 < Test::Unit::TestCase
  include TestMixin

  def test_speed1
    1.upto(10000) do
      wf = TestWorkflow.new
      wf.description do
        choose :c1 do
          alternative :c1_1, true do
            call :a_1, :endpoint1
          end
          alternative :c1_2, false do
            call :a_2, :endpoint1
          end
          otherwise :c1_3 do
            call :a_3, :endpoint1
          end
        end
      end
      wf.start.join
    end  
  end

end

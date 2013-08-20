require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../TestWorkflow')

class TestWFPExclusiveChoice < Test::Unit::TestCase
  include TestMixin

  def test_exclusive_choice
    @wf.description do
      choose do
        alternative(true) do
          call :a1_1, :endpoint1
        end
        otherwise do
          call :a1_2, :endpoint1
        end
      end
    end
    @wf.start.join
    wf_assert("CALL a1_1: passthrough=[], endpoint=[http://www.heise.de], parameters=[{}]")
    wf_assert("CALL a1_2:",false)
  end  
end

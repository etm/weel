require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../TestWorkflow')

class TestSpeed2 < Test::Unit::TestCase
  include TestMixin

  def test_speed2
    wf = TestWorkflow.new
    wf.description do
      1.upto(10000) do
        call :a_1, :endpoint1
      end    
    end
    wf.start.join
  end

end

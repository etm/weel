require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../TestWorkflow')

class TestChoose < Test::Unit::TestCase
  include TestMixin

  def test_exec
    @wf.data[:a] = 0
    @wf.data[:b] = 0
    @wf.description do
      manipulate :a_1, <<-end
        data.a = 1 
      end
      call :a_2, :endpoint1 do
        data.b = 1
      end
    end
    @wf.start.join
    wf_assert("MANIPULATE a_1")
    wf_assert("CALL a_2")
    assert(@wf.data[:a] == 1)
    assert(@wf.data[:b] == 1)
  end

end

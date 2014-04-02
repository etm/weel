require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../TestWorkflow')

class TestChoose < Test::Unit::TestCase
  include TestMixin

  def test_again
    @wf.data[:a] = 0
    @wf.description do
      call :a_1, :again, :call => Proc.new{data.a < 2}  do
        data.a += 1
      end
    end
    @wf.start.join
    wf_assert("CALL a_1")
    wf_sassert("|running|Ca_1Ma_1Ca_1Ma_1Ca_1Ma_1Da_1|finished|")
    assert(@wf.data[:a] == 3)
  end

end

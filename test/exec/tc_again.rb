require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../TestWorkflow')

class TestAgain < Test::Unit::TestCase
  include TestMixin

  def test_again
    @wf.data[:a] = 0
    $again_count = 0
    @wf.description do
      # the handler asks :again before each answer: twice update, then finalize
      call :a_1, :again, parameters: { :again => Proc.new{ ($again_count += 1) < 3 } }, update: 'data.a += 1', finalize: 'data.a += 1'
    end
    @wf.start.join
    wf_assert("CALL a_1")
    wf_sassert("|running|Ca_1Ma_1Ma_1Ma_1Da_1|finished|")
    assert(@wf.data[:a] == 3)
  end

end

require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../TestWorkflow')

class TestCodeReplace < Test::Unit::TestCase
  include TestMixin

  def test_replace
    @wf.description do
      call :a_test_1_1, :endpoint1
      call :a_test_1_2, :endpoint1
      call :a_test_1_3, :endpoint1
    end
    @wf.search WEEL::Position.new(:a_test_1_1, :at)
    @wf.start.join
    wf_assert("CALL a_test_1_1:")
    wf_assert("CALL a_test_1_2:")
    wf_assert("CALL a_test_1_3:")
    wf_sassert("|running|Ca_test_1_1Da_test_1_1Ca_test_1_2Da_test_1_2Ca_test_1_3Da_test_1_3|finished|")
  end
  #def test_wfdescription_string
  #  ret = @wf.description "call :b_test_1_1, :endpoint1"
  #  @wf.search WEEL::Position.new(:b_test_1_1, :at)
  #  @wf.start.join
  #  wf_assert("DONE b_test_1_1")
  #  wf_sassert("|running|Cb_test_1_1Db_test_1_1|finished|")
  #end
  def test_wfdescription_block
    ret = @wf.description do
      call :c_test_1_1, :endpoint1
      call :c_test_1_2, :endpoint1
    end

    assert(ret.class == Proc, "wf_description should be nil => not available. codeblock was given!")
    @wf.search WEEL::Position.new(:c_test_1_2, :at)
    @wf.start.join
    wf_sassert("|running|Cc_test_1_2Dc_test_1_2|finished|")
  end
end

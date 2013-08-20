require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../TestWorkflow')

class TestSearch < Test::Unit::TestCase
  include TestMixin

  def test_search_impact_single
    @wf.description do
      call :a1_1, :endpoint1
      call :a1_2, :endpoint1
      call :a1_3, :endpoint1
    end
    @wf.search WEEL::Position.new(:a1_2, :at)
    @wf.start.join
    wf_sassert("|running|Ca1_2Da1_2Ca1_3Da1_3|finished|")
  end
  def test_search_impact_dual
    @wf.description do
      call :a1, :endpoint1
      parallel do
        parallel_branch do
          call :a2_1, :endpoint1
        end
        parallel_branch do
          call :a2_2, :endpoint1
        end
      end
      call :a3, :endpoint1
    end
    @wf.search [WEEL::Position.new(:a2_1, :at), WEEL::Position.new(:a2_2, :at)]
    @wf.start.join
    wf_assert("DONE a1",false)
    wf_assert("DONE a2_1",true)
    wf_assert("DONE a2_2",true)
    wf_assert("DONE a3",true)
  end
end

require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../TestWorkflow')

class TestAdventureSearch < Test::Unit::TestCase
  include TestMixin

  def test_search_adventure
    @wf.data[:oee] = 0.25
    @wf.description = File.read(__dir__ + '/dsl1')
    @wf.search [WEEL::Position.new(:a2, :at), WEEL::Position.new(:a13, :at)]
    @wf.start.join

    wf_assert("DONE a2",true)
    wf_assert("DONE a13",true)
  end
end

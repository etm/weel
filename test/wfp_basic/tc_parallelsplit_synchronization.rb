require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../TestWorkflow')

class TestWFPParallel < Test::Unit::TestCase
  include TestMixin

  def test_parallel_split
    @wf.description do
      parallel :wait do
        parallel_branch do
          call :a1_1, :endpoint1
        end
        parallel_branch do
          call :a1_2, :endpoint1
        end
      end
      call :a2, :endpoint1
    end
    @wf.start.join
    wf_assert('CALL a1_1')
    wf_assert('CALL a1_2')
    wf_assert('DONE a1_1')
    wf_assert('DONE a1_2')
    wf_sassert('Ca2Da2|finished|')
  end
end

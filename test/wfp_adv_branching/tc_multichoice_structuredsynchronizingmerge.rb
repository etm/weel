require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../TestWorkflow')

class TestWFPMultiChoice < Test::Unit::TestCase
  include TestMixin

  def test_multichoice_chained
    @wf.data :x => 1
    @wf.description do
      choose do
        alternative(data.x == 1) do
          call :a1_1, :endpoint1
        end
        alternative(data.x > 0) do
          call :a1_2, :endpoint1
        end
      end
      call :a2, :endpoint1
    end
    @wf.start.join
    wf_sassert('|running|Ca1_1Da1_1Ca1_2Da1_2Ca2Da2|finished|')
  end
  def test_multichoice_parallel
    @wf.data :x => 1
    @wf.description do
      choose do
        parallel do
          parallel_branch do
            alternative(data.x == 1) do
              call :a1_1, :endpoint1
              Thread.pass
            end
          end
          parallel_branch do
            alternative(data.x > 0) do
              call :a1_2, :endpoint1, parameters: { :call => Proc.new{sleep 0.5} }
            end
          end
        end
      end
      call :a2, :endpoint1
    end
    @wf.start.join
    wf_assert('CALL a1_1')
    wf_assert('CALL a1_2')
    wf_sassert('Da1_2Ca2Da2|finished|')
  end
end

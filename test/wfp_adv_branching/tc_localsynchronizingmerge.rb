require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../TestWorkflow')

class TestWFPLocalSynchronizingMerge < Test::Unit::TestCase
  include TestMixin

  def test_localsyncmerge
    @wf.description do
      parallel :p1 do
        parallel_branch :p1_1 do
          call :a1_1, :endpoint1, parameters: { :call => Proc.new{sleep 0.2} }
        end
        parallel_branch :p1_2 do
          call :a1_2, :endpoint1, parameters: { :call => Proc.new{sleep 0.4} }
        end
        choose :c1 do
          alternative(:c1_1, false) do
            parallel_branch :p1_3 do
              call :a2_1, :endpoint1
            end
          end
          otherwise :c1_2 do
            call :a2_2, :endpoint1, parameters: { :call => Proc.new{sleep 0.1} }
          end
        end
      end
      call :a3, :endpoint1
    end
    @wf.start.join
    wf_sassert('|running|Ca2_2Da2_2')
    wf_assert('CALL a1_1:')
    wf_assert('CALL a1_2:')
    wf_assert('DONE a1_1')
    wf_assert('DONE a1_2')
    wf_sassert('Ca3Da3|finished|')
  end
end

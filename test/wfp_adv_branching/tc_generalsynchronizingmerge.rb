require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../TestWorkflow')

class TestWFPGeneralSynchronizingMerge < Test::Unit::TestCase
  include TestMixin

  def test_generalsyncmerge
    @wf.data[:cont] = true
    @wf.description do
      parallel :p1 do
        parallel_branch :p1_1 do
          call :a1_1, :endpoint1, parameters: { :call => Proc.new{sleep 0.2} }
        end
        parallel_branch :p1_2 do
          call :a1_2, :endpoint1, parameters: { :call => Proc.new{sleep 0.4} }
        end
        choose :c1 do
          alternative(:c1_1, true) do
            loop :l1, post_test('data.break') do
              parallel_branch :p1_3 do
                call :a2_1, :endpoint1
              end
              call(:a2_decide, :endpoint1, parameters: { :result => false}, finalize: 'data.break = result')
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
    wf_sassert('|running|Ca2_decideMa2_decideDa2_decide')
    wf_assert('CALL a1_1:')
    wf_assert('CALL a1_2:')
    wf_assert('CALL a2_1:')
    wf_assert('DONE a1_1')
    wf_assert('DONE a1_2')
    wf_assert('DONE a2_1')
    wf_sassert('Ca3Da3|finished|')
  end
end

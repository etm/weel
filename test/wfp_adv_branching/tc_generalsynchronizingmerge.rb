require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../TestWorkflow')

class TestWFPGeneralSynchronizingMerge < Test::Unit::TestCase
  include TestMixin

  def test_generalsyncmerge
    @wf.data[:cont] = true
    @wf.description do
      parallel do
        parallel_branch do
          call :a1_1, :endpoint1, parameters: { :call => Proc.new{sleep 0.2} }
        end
        parallel_branch do
          call :a1_2, :endpoint1, parameters: { :call => Proc.new{sleep 0.4} }
        end
        choose do
          alternative(true) do
            loop post_test{data.break} do
              parallel_branch do
                call :a2_1, :endpoint1
              end  
              call(:a2_decide, :endpoint1, parameters: { :result => false}) do |e|
                data.break = e
              end
            end  
          end
          otherwise do
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

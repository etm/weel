require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../TestWorkflow')

class TestParallelStop < Test::Unit::TestCase
  include TestMixin

  def test_coopis
    @wf.data[:hotels]  = []
    @wf.data[:costs]   = 0
    @wf.description do
      parallel do
        parallel_branch do
          call :a1, :endpoint1 do
            data.hotels << 'Rathaus'
            data.costs += 200
          end
          call :a3, :stop
        end
        parallel_branch do
          call :a2, :endpoint2 do
            data.hotels << 'Graf Stadion'
            data.costs += 200
          end
          call :a4, :stop
        end
      end
    end
    @wf.start.join

    wf_rsassert('\|stopped\|')
  end
end

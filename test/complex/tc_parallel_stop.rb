require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../TestWorkflow')

class TestParallelStop < Test::Unit::TestCase
  include TestMixin

  def test_coopis
    @wf.data[:hotels]  = []
    @wf.data[:costs]   = 0
    @wf.description do
      parallel :p1 do
        parallel_branch :p1_1 do
          call :a1, :endpoint1, finalize: <<-END
            data.hotels << 'Rathaus'
            data.costs += 200
          END
          call :a3, :stop
        end
        parallel_branch :p1_2 do
          call :a2, :endpoint2, finalize: <<-END
            data.hotels << 'Graf Stadion'
            data.costs += 200
          END
          call :a4, :stop
        end
      end
    end
    @wf.start.join

    wf_rsassert('\|stopped\|')
  end
end

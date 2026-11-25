require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../TestWorkflow')

class TestGeneralsynchonizingmergeLoopsearch < Test::Unit::TestCase
  include TestMixin

  def test_coopis
    @wf.data[:hotels]  = []
    @wf.data[:airline] = ''
    @wf.data[:costs]   = 0
    @wf.data[:persons] = 3
    @wf.description do
      call :a1, :endpoint1, finalize: <<-END
        data.airline = 'Aeroflot'
        data.costs  += 101
        status.update 1, 'Hotel'
      END
      parallel :p1 do
        loop :l1, pre_test('data.persons > 0') do
          parallel_branch :p1_1 do |p|
            call :a2, :endpoint1, finalize: <<-END
              data.hotels << 'Rathaus'
              data.costs += 200
            END
          end
          manipulate :a3, 'data.persons -= 1'
        end
      end
      choose :c1 do
        alternative :c1_1, 'data.costs > 400' do
          call :a4, :endpoint1
        end
      end
    end
    @wf.start.join

    wf_rsassert('\|running\|Ca1Ma1Da1Ma3Da3Ma3Da3Ma3Da3Ca2.*?Ca2.*?Ca2.*Da2Ca4Da4\|finished\|')
  end

  def test_coopis_searchmode1
    @wf.data[:hotels]  = ['Marriott']
    @wf.data[:airline] = 'Ana'
    @wf.data[:costs]   = 802
    @wf.data[:persons] = 2
    @wf.description do
      call :a1, :endpoint1, finalize: <<-END
        data.airline = 'Aeroflot'
        data.costs  += 101
        status.update 1, 'Hotel'
      END
      parallel :p1 do
        loop :l1, pre_test('data.persons > 0') do
          parallel_branch :p1_1 do |p|
            call :a2, :endpoint1, finalize: <<-END
              data.hotels << 'Rathaus'
              data.costs += 200
            END
          end
          manipulate :a3, 'data.persons -= 1'
        end
      end
      choose :c1 do
        alternative :c1_1, 'data.costs > 700' do
          call :a4, :endpoint1
        end
      end
    end
    @wf.search [WEEL::Position.new(:a3, 0, :at)]
    @wf.start.join
    
    wf_rsassert('\|running\|Ma3Da3Ma3Da3Ca2.*?Ca2.*Da2Ca4Da4\|finished\|')
  end

  def test_coopis_searchmode2
    @wf.data[:hotels]  = ['Marriott']
    @wf.data[:airline] = 'Ana'
    @wf.data[:costs]   = 802
    @wf.data[:persons] = 2
    @wf.description do
      call :a1, :endpoint1, finalize: <<-END
        data.airline = 'Aeroflot'
        data.costs  += 101
        status.update 1, 'Hotel'
      END
      parallel :p1 do
        loop :l1, pre_test('data.persons > 0') do
          parallel_branch :p1_1 do |p|
            call :a2, :endpoint1, finalize: <<-END
              data.hotels << 'Rathaus'
              data.costs += 200
            END
          end
          manipulate :a3, 'data.persons -= 1'
        end
      end
      choose :c1 do
        alternative :c1_1, 'data.costs > 700' do
          call :a4, :endpoint1
        end
      end
    end
    @wf.search [WEEL::Position.new(:a2, 0, :at)]
    @wf.start.join
    
    wf_rsassert('\|running\|Ca2Ma2Da2Ca4Da4\|finished\|')
  end
end

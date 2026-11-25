require File.expand_path(::File.dirname(__FILE__) + '/../lib/weel')
require File.expand_path(::File.dirname(__FILE__) + '/TestMixin')
require File.expand_path(::File.dirname(__FILE__) + '/TestConnectionWrapper')

class TestWorkflow < WEEL
  connectionwrapper TestConnectionWrapper

  endpoint :endpoint1 => 'http://www.heise.de'
  endpoint :stop => 'stop it'
  endpoint :again => 'again'
  data :x => 'begin_'

  control flow do
    call :a1_1, :endpoint1, finalize: 'data.x += "#{result}"'
    parallel :p1 do
      parallel_branch :p1_1 do
        call :a2_1_1, :endpoint1
      end
      parallel_branch :p1_2 do
        call :a2_2_1, :endpoint1
      end
    end
    manipulate :a3, "data.x += '_end'"
    choose :c1 do
      alternative :c1_1, 'data.x != nil' do
        call :a4a, :endpoint1
      end
      otherwise :c1_2 do
        call :a4b, :endpoint1
      end
    end
  end
end

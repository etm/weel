require File.expand_path(::File.dirname(__FILE__) + '/../lib/weel')
require File.expand_path(::File.dirname(__FILE__) + '/TestMixin')
require File.expand_path(::File.dirname(__FILE__) + '/TestHandlerWrapper')

class TestWorkflow < WEEL
  handlerwrapper TestHandlerWrapper

  endpoint :endpoint1 => 'http://www.heise.de'
  endpoint :stop => 'stop it'
  endpoint :again => 'again'
  data :x => 'begin_'

  control flow do
    call :a1_1, :endpoint1 do |result|
      data.x += "#{result}"
    end
    parallel :wait do
      parallel_branch do
        call :a2_1_1, :endpoint1
      end
      parallel_branch do
        call :a2_2_1, :endpoint1
      end
    end
    manipulate :a3 do
      data.x += '_end'
    end
    choose do
      alternative data.x != nil do
        call :a4a, :endpoint1
      end
      otherwise do
        call :a4b, :endpoint1
      end
    end
  end
end

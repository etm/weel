# Apache License, Version 2.0
# 
# Copyright (c) 2013 Juergen Mangler
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

######
# ADVENTURE Simulation Trace Generator Handler Wrapper
######

module TraceBasics #{{{
  def <<(item)
    @elements << item
    item.parent = self  
  end
  def each
    @elements.each do |ele|
      yield ele
    end  
  end
end #}}}

class Trace
  include TraceBasics
  attr_accessor :elements
  def initialize
    @elements = []
  end

  def last_parallel
    container = last_container
    unless container.kind_of?(TraceParallel)
      container = container.parent 
    end
    container
  end
  def last_parallel_branch(tid)
    container = last_parallel
    container.each do |ele|
      return ele if ele.tid == tid
    end  
    nil
  end

  def get_container(tid)
    recursive_get_container(self,tid) || self
  end
  def recursive_get_container(container,tid)
    return container if container.respond_to?(:tid) and container.tid == tid
    container.each do |ele| 
      if ele.kind_of?(TraceContainer)
        ret = recursive_get_container(ele,tid) 
        return ret unless ret.nil?
      end  
    end
    nil
  end

  def last_container
    recursive_last_container self
  end
  def recursive_last_container(container)
    return container if container.elements.empty?
    element = container.elements.last
    if element.kind_of?(TraceContainer) && element.open?
      recursive_last_container element
    else  
      container
    end
  end

  private :recursive_last_container
end

class TraceBase #{{{
  attr_accessor :tid, :parent
  def initialize(tid)
    @tid = tid
    @parent = nil
  end
end #}}}

class TraceContainer < TraceBase #{{{
  include TraceBasics
  attr_accessor :elements
  def initialize(tid)
    super tid
    @elements = []
    @open = true
  end
  def open?; @open; end
  def close!; @open = false; end
end #}}}

class TraceElement < TraceBase #{{{
  attr_accessor :item
  def initialize(tid, item)
    super tid
    @item = item
  end
end #}}}

class TraceParallel < TraceContainer; end
class TraceParallelBranch < TraceContainer; end
class TraceLoop < TraceContainer; end

$trace = Trace.new

class SimHandlerWrapper < WEEL::HandlerWrapperBase
  def initialize(args,endpoint=nil,position=nil,continue=nil)
    @__myhandler_stopped = false
    @__myhandler_position = position
    @__myhandler_continue = continue
    @__myhandler_endpoint = endpoint
    @__myhandler_returnValue = nil
  end

  def simulate_alternative(type,nesting,tid,parent,parameters={}) #{{{
    pp "#{type} - #{nesting} - #{tid} - #{parameters.inspect}"

    case type
      when :activity
        $trace.last_container << TraceElement.new(tid,parameters[:endpoint])
      when :parallel
        if nesting == :start
          clast = $trace.last_container
          clast << TraceParallel.new(tid)
        else
          clast = $trace.last_parallel
          clast.close! if clast.open?
        end  
      when :loop
        pp $trace
        clast = $trace.last_container
        if nesting == :start
          clast << TraceLoop.new(tid)
        else
          if clast && clast.tid == tid && clast.open?
            clast.close!
          end
        end  
      when :parallel_branch
        if nesting == :start
          clast = $trace.last_parallel
          clast << TraceParallelBranch.new(tid)
        else
          clast = $trace.last_parallel_branch(tid)
          clast.close! if clast.open?
        end  
    end  
  end #}}}

end

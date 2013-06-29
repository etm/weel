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

class Trace #{{{
  include TraceBasics
  attr_accessor :elements
  def initialize
    @elements = []
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

  def generate_list
    pp self
    pp recursive_generate_list(self,:otherwise=>false)
  end

  def recursive_generate_list(container,options)
    traces = [[]]
    container.each do |ele|
      case ele
        when TraceActivity
          traces.last << ele.tid
        when TraceChoose
          options[:otherwise] = true
          tmp = recursive_generate_list(ele,options)
          options[:otherwise] = false
          add_traces(traces,tmp)

          #tmp = recursive_generate_list(ele,options)
        when TraceAlternative
          next if options[:otherwise]
          tmp = recursive_generate_list(ele,options)
          add_traces(traces,tmp)
        when TraceOtherwise
          next unless options[:otherwise]
          options[:otherwise] = false
          tmp = recursive_generate_list(ele,options)
          add_traces(traces,tmp)
          options[:otherwise] = true
      end  
    end
    traces
  end

  def add_traces(before,newones)
    before.each do |trc|
      newones.each do |no|
        trc += no
      end
    end
  end

  private :recursive_get_container
end #}}}

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

class TraceActivity < TraceBase #{{{
  attr_accessor :item
  def initialize(tid, item)
    super tid
    @item = item
  end
end #}}}

class TraceParallel < TraceContainer; end
class TraceParallelBranch < TraceContainer #{{{
  def initialize(tid,group_by)
    super tid
    @group_by = group_by
  end
  attr_reader :group_by
end #}}}
class TraceLoop < TraceContainer; end
class TraceChoose < TraceContainer
  attr_reader :mode
  def initialize(tid,mode)
    super tid
    @mode = mode
  end  
end
class TraceAlternative < TraceContainer; end
class TraceOtherwise < TraceContainer; end

class PlainTrace
  def initialize
    @container
  end  
end

class SimHandlerWrapper < WEEL::HandlerWrapperBase
  def initialize(args,endpoint=nil,position=nil,continue=nil)
    @__myhandler_stopped = false
    @__myhandler_position = position
    @__myhandler_continue = continue
    @__myhandler_endpoint = endpoint
    @__myhandler_returnValue = nil
  end

  def simulate(type,nesting,tid,parent,parameters={})
    # pp "#{type} - #{nesting} - #{tid} - #{parent} - #{parameters.inspect}"

    case type
      when :activity
        $trace.get_container(parent) << TraceActivity.new(tid,parameters[:endpoint])
      when :parallel
        simulate_add_to_container($trace,nesting,parent,tid) { TraceParallel.new(tid) }
      when :loop
        simulate_add_to_container($trace,nesting,parent,tid) { TraceLoop.new(tid) }
      when :parallel_branch
        if nesting == :start
          clast = $trace.get_container(parent)
          until clast.kind_of?(TraceParallel)
            clast = clast.parent
          end  
          clast << TraceParallelBranch.new(tid,parent)
        else
          clast = $trace.get_container(tid)
          clast.close! if clast.open?
        end  
      when :choose
        simulate_add_to_container($trace,nesting,parent,tid) { TraceChoose.new(tid,parameters[:mode]) }
      when :alternative
        simulate_add_to_container($trace,nesting,parent,tid) { TraceAlternative.new(tid) }
      when :otherwise
        simulate_add_to_container($trace,nesting,parent,tid) { TraceOtherwise.new(tid) }
    end  
  end

  private

    def simulate_add_to_container(trace,nesting,parent,tid) #{{{
      if nesting == :start
        clast = trace.get_container(parent)
        clast << yield
      else
        clast = trace.get_container(tid)
        clast.close! if clast.open?
      end  
    end #}}}

end

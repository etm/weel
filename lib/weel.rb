# encoding: utf-8
#
# This file is part of WEEL.
#
# WEEL is free software: you can redistribute it and/or modify it under the terms
# of the GNU General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# WEEL is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# WEEL (file COPYING in the main directory).  If not, see
# <http://www.gnu.org/licenses/>.

require 'thread'
require 'securerandom'

class WEEL
  def initialize(*args)# {{{
    @dslr = DSLRealization.new
    @dslr.__weel_connectionwrapper_args = args

    initialize_search if methods.include?(:initialize_search)
    initialize_data if methods.include?(:initialize_data)
    initialize_endpoints if methods.include?(:initialize_endpoints)
    initialize_connectionwrapper if methods.include?(:initialize_connectionwrapper)
    initialize_control if methods.include?(:initialize_control)
    initialize_flow_data if methods.include?(:initialize_flow_data)
  end # }}}

  module Signal # {{{
    class Skip < Exception; end
    class SkipManipulate < Exception; end
    class StopSkipManipulate < Exception; end
    class Stop < Exception; end
    class Proceed < Exception; end
    class NoLongerNecessary < Exception; end
    class Again < Exception; end
    class Error < Exception; end
    class Salvage < Exception; end
  end # }}}

  class ReadStructure # {{{
    def initialize(data,endpoints,local,additional)
      @__weel_data = data.transform_values do |v|
        if Object.const_defined?(:XML) && XML.const_defined?(:Smart) && v.is_a?(XML::Smart::Dom)
          v.root.to_doc
        else
          begin
            Marshal.load(Marshal.dump(v))
          rescue
            v.to_s rescue nil
          end
        end
      end
      @__weel_endpoints = endpoints.transform_values{ |v| v.dup }
      @__weel_local = local
      @additional = additional
    end

    def to_json(*a)
      {
        'data' => @__weel_data,
        'endpoints' => @__weel_endpoints,
        'additional' => @additional,
        'status' => {
          'id' => @__weel_status.id,
          'message' => @__weel_status.message
        }
      }.to_json(*a)
    end

    def method_missing(m,*args,&block)
      if @additional.include?(m)
        begin
          tmp = Marshal.load(Marshal.dump(@additional[m]))
          if tmp.is_a? Hash
            ReadHash.new(tmp)
          else
            tmp
          end
        rescue
          m.to_s rescue nil
        end
      end
    end
    def data
      ReadHash.new(@__weel_data)
    end
    def endpoints
      ReadHash.new(@__weel_endpoints)
    end
    def local
      @__weel_local.first
    end
  end # }}}
  class ManipulateStructure # {{{
    def initialize(data,endpoints,status,local,additional)
      @__weel_data = data
      @__weel_data_orig = @__weel_data.transform_values{|val| Marshal.dump(val) } rescue nil
      @__weel_endpoints = endpoints
      @__weel_endpoints_orig = @__weel_endpoints.transform_values{|val| Marshal.dump(val) }
      @__weel_status = status
      @__weel_local = local
      @changed_status = "#{status.id}-#{status.message}"
      @changed_data = []
      @touched_data = []
      @changed_endpoints = []
      @touched_endpoints = []
      @additional = additional
    end

    def to_json(*a)
      {
        'data' => @__weel_data,
        'endpoints' => @__weel_endpoints,
        'additional' => @additional,
        'status' => {
          'id' => @__weel_status.id,
          'message' => @__weel_status.message
        }
      }.to_json(*a)
    end

    def method_missing(m,*args,&block)
      if @additional.include?(m)
        begin
          tmp = Marshal.load(Marshal.dump(@additional[m]))
          if tmp.is_a? Hash
            ReadHash.new(tmp)
          else
            tmp
          end
        rescue
          m.to_s rescue nil
        end
      end
    end

    def changed_data
      @touched_data.each do |e|
        td = Marshal.dump(@__weel_data[e]) rescue nil
        if td != @__weel_data_orig[e]
          @changed_data << e
        end
      end
      @changed_data
    end
    def changed_endpoints
      @changed_endpoints
    end

    def original_data
      @__weel_data_orig.transform_values{|val| Marshal.load(val) rescue nil }
    end

    def original_endpoints
      @__weel_endpoints_orig.transform_values{|val| Marshal.load(val) rescue nil }
    end

    def changed_status
      @changed_status != "#{status.id}-#{status.message}"
    end

    def data
      ManipulateHash.new(@__weel_data,@touched_data,@changed_data)
    end
    def endpoints
      ManipulateHash.new(@__weel_endpoints,@touched_endpoints,@changed_endpoints)
    end
    def local
      @__weel_local.first
    end
    def status
      @__weel_status
    end
  end # }}}
  class ManipulateHash # {{{
    attr_reader :__weel_touched, :__weel_changed

    def initialize(values,touched,changed)
      @__weel_values = values
      @__weel_touched = touched
      @__weel_changed = changed
    end

    def delete(value)
      if @__weel_values.key?(value)
        @__weel_changed << value
        @__weel_values.delete(value)
      end
    end

    def clear
      @__weel_changed += @__weel_values.keys
      @__weel_values.clear
    end

    def method_missing(name,*args)
      if args.empty? && @__weel_values.key?(name)
        @__weel_touched << name
        @__weel_values[name]
      elsif name.to_s[-1..-1] == "=" && args.length == 1
        temp = name.to_s[0..-2]
        @__weel_changed << temp.to_sym
        @__weel_values[temp.to_sym] = args[0]
      elsif name.to_s == "[]=" && args.length == 2
        @__weel_changed << args[0]
        @__weel_values[args[0]] = args[1]
      elsif name.to_s == "[]" && args.length == 1
        @__weel_touched << args[0]
        @__weel_values[args[0]]
      else
        nil
      end
    end
  end # }}}

  class Status # {{{
    def initialize(id,message)
      @id      = id
      @message = message
      @nudge   = Queue.new
    end
    def update(id,message)
      @id      = id
      @message = message
    end
    def nudge!
      1.upto(@nudge.num_waiting) do
        @nudge.push(nil)
      end
    end
    def wait_until_nudged!
      @nudge.pop
    end
    attr_reader :id, :message
  end #}}}

  class ReadHash # {{{
    def initialize(values,sim=false)
      @__weel_values = values
      @__weel_sim = sim
    end

    def to_json(*args)
      @__weel_values.to_json(*args)
    end

    def method_missing(name,*args)
      if @__weel_sim
        "➤#{name}"
      else
        if args.empty? && @__weel_values.key?(name)
          @__weel_values[name]
        elsif args.empty? && @__weel_values.key?(name.to_s)
          @__weel_values[name.to_s]
        elsif name.to_s[-1..-1] == "=" && args.length == 1
          temp = name.to_s[0..-2]
          @__weel_values[temp.to_sym] = args[0]
        elsif name.to_s == "[]=" && args.length == 2
          @__weel_values[args[0]] = args[1]
        elsif name.to_s == "[]" && args.length == 1
          @__weel_values[args[0]]
        else
          nil
        end
      end
    end
  end # }}}

  class ReadOnlyHash # {{{
    def initialize(values,sim=false)
      @__weel_values = values.transform_values do |v|
        if Object.const_defined?(:XML) && XML.const_defined?(:Smart) && v.is_a?(XML::Smart::Dom)
          v.root.to_doc
        else
          begin
            Marshal.load(Marshal.dump(v))
          rescue
            v.to_s rescue nil
          end
        end
      end
      @__weel_sim = sim
    end

    def to_json(*args)
      @__weel_values.to_json(*args)
    end

    def method_missing(name,*args)
      if @__weel_sim
        "➤#{name}"
      else
        if args.empty? && @__weel_values.key?(name)
          @__weel_values[name]
        elsif args.empty? && @__weel_values.key?(name.to_s)
          @__weel_values[name.to_s]
        elsif name.to_s[-1..-1] == "=" && args.length == 1
          temp = name.to_s[0..-2]
          @__weel_values[temp.to_sym] = args[0]
        elsif name.to_s == "[]=" && args.length == 2
          @__weel_values[args[0]] = args[1]
        elsif name.to_s == "[]" && args.length == 1
          @__weel_values[args[0]]
        else
          nil
        end
      end
    end
  end # }}}

  class ConnectionWrapperBase # {{{
    def self::loop_guard(arguments,lid,count); false; end
    def self::inform_state_change(arguments,newstate); end
    def self::inform_syntax_error(arguments,err,code); end
    def self::inform_connectionwrapper_error(arguments,err); end
    def self::inform_position_change(arguments,ipc={}); end

    def initialize(arguments,position=nil,continue=nil); end

    def prepare(readonly, endpoints, parameters, replay=false); parameters; end
    def additional; {}; end

    def activity_handle(passthrough, parameters); end
    def activity_manipulate_handle(parameters); end

    def activity_result_value; end
    def activity_result_options; end

    def activity_stop; end
    def activity_passthrough_value; end
    def activity_uuid; '42424242-cpee-cpee-cpee-424242424242'; end

    def activity_no_longer_necessary; end

    def inform_activity_done; end
    def inform_activity_manipulate; end
    def inform_activity_failed(err); end
    def inform_manipulate_change(status,changed_data,changed_endpoints,data,endpoints); end

    def vote_sync_before(parameters=nil); true; end
    def vote_sync_after; true; end

    # type       => activity, loop, parallel, choice
    # nesting    => none, start, end
    # eid        => id's also for control structures
    # parameters => stuff given to the control structure
    def simulate(type,nesting,sequence,parent,parameters={}); end

    def callback(result=nil,options={}); end
    def mem_guard; end

    def test_condition(mr,code); mr.instance_eval(code); end
    def join_branches(branches); end
    def manipulate(mr,code,where,result=nil,options=nil); mr.instance_eval(code,where,1); end
  end  # }}}

  class Position # {{{
    attr_reader :position, :uuid
    attr_accessor :detail, :passthrough
    def initialize(position, uuid, detail=:at, passthrough=nil) # :at or :after or :unmark
      @position = position
      @detail = detail
      @uuid = uuid
      @passthrough = passthrough
    end
    def as_json(*)
      jsn = { 'position' => @position, 'uuid' => @uuid }
      jsn['passthrough'] = @passthrough if @passthrough
      jsn
    end
    def to_s
      as_json.to_s
    end
    def to_json(*args)
      as_json.to_json(*args)
    end
    def eql?(other)
      to_s == other.to_s
    end
    def hash
      to_s.hash
    end
  end # }}}

   class Continue # {{{
     def initialize
       @q = Queue.new
       @m = Mutex.new
     end
     def waiting?
       @m.synchronize do
         !@q.empty?
       end
     end
     def continue(*args)
       @q.push(args.length <= 1 ? args[0] : args)
     end
     def clear
      @q.clear
     end
     def wait
       @q.deq
     end
   end #}}}

  def self::search(*weel_search)# {{{
    define_method :initialize_search do
      self.search weel_search
    end
  end # }}}
  def self::endpoint(new_endpoints)# {{{
    @@__weel_new_endpoints ||= {}
    @@__weel_new_endpoints.merge! new_endpoints
    remove_method :initialize_endpoints if method_defined? :initialize_endpoints
    define_method :initialize_endpoints do
      @@__weel_new_endpoints.each do |name,value|
        @dslr.__weel_endpoints[name.to_s.to_sym] = value
      end
    end
  end # }}}
  def self::data(data_elements)# {{{
    @@__weel_new_data_elements ||= {}
    @@__weel_new_data_elements.merge! data_elements
    define_method :initialize_data do
      @@__weel_new_data_elements.each do |name,value|
        @dslr.__weel_data[name.to_s.to_sym] = value
      end
    end
  end # }}}
  def self::connectionwrapper(aClassname, *args)# {{{
    define_method :initialize_connectionwrapper do
      self.connectionwrapper = aClassname
      self.connectionwrapper_args = args unless args.empty?
    end
  end # }}}
  def self::control(flow, &block)# {{{
    define_method :initialize_control do
      self.description = block
    end
  end #  }}}
  def self::flow(flow_data=nil) # {{{
    define_method :initialize_flow_data do
      self.flow_data = flow_data
    end if flow_data
  end #}}}

  class DSLRealization # {{{
    def  initialize #{{{
      @__weel_search_positions = {}
      @__weel_positions = Array.new
      @__weel_main = nil
      @__weel_data ||= Hash.new
      @__weel_endpoints ||= Hash.new
      @__weel_connectionwrapper = ConnectionWrapperBase
      @__weel_connectionwrapper_args = []
      @__weel_state = :ready
      @__weel_status = Status.new(0,"undefined")
      @__weel_replay = false
      @__weel_sim = -1
    end #}}}
    attr_accessor :__weel_search_positions, :__weel_positions, :__weel_main, :__weel_data, :__weel_endpoints, :__weel_connectionwrapper, :__weel_connectionwrapper_args, :__weel_replay
    attr_reader :__weel_state, :__weel_status

    # DSL-Constructs for atomic calls to external services (calls) and pure context manipulations (manipulate).
    # Calls can also manipulate context (after the invoking the external services)
    # position: a unique identifier within the wf-description (may be used by the search to identify a starting point)
    # endpoint: (only with :call) ep of the service
    # parameters: (only with :call) service parameters
    def call(position, endpoint, parameters: {}, finalize: nil, update: nil, prepare: nil, salvage: nil, &finalizeblk) #{{{
      __weel_activity(position,:call,endpoint,parameters,finalize||finalizeblk,update,prepare,salvage)
    end #}}}
    # when two params, second param always script
    # when block and two params, parameters stays
    def manipulate(position, parameters=nil, script=nil, &scriptblk) #{{{
      if scriptblk.nil? && script.nil? && !parameters.nil?
        script, parameters = parameters, nil
      end
      __weel_activity(position,:manipulate,nil,parameters||{},script||scriptblk)
    end #}}}

    # Parallel DSL-Construct
    # Defines Workflow paths that can be executed parallel.
    # May contain multiple branches (parallel_branch)
    def parallel(type=nil,&block)# {{{
      return if self.__weel_state == :stopping || self.__weel_state == :finishing || self.__weel_state == :stopped

      Thread.current[:branches] = []
      Thread.current[:branch_traces] = {}
      Thread.current[:branch_traces_ids] = 0
      Thread.current[:branch_finished_count] = 0
      Thread.current[:branch_event] = Continue.new
      Thread.current[:mutex] = Mutex.new

      hw, pos = __weel_sim_start(:parallel) if __weel_sim

      __weel_protect_yield(&block)

      Thread.current[:branch_wait_count] = (type.is_a?(Hash) && type[:wait] != nil && (type[:wait].is_a?(Integer) && type[:wait] > 0) ? type[:wait] : Thread.current[:branches].size)
      Thread.current[:branch_wait_count_cancel] = 0
      Thread.current[:branch_wait_count_cancel_condition] = (type.is_a?(Hash) && type[:cancel] != nil && type[:cancel] == :first ) ? :first : :last
      1.upto Thread.current[:branches].size do
        Thread.current[:branch_event].wait
      end

      Thread.current[:branches].each do |thread|
        # decide after executing block in parallel cause for coopis
        # it goes out of search mode while dynamically counting branches
        if Thread.current[:branch_search] == false
          thread[:branch_search] = false
        end
        thread[:start_event]&.continue # sometimes start event might not even exist yet (i.e. race condition)
      end

      Thread.current[:branch_event].wait unless self.__weel_state == :stopping || self.__weel_state == :finishing || self.__weel_state == :stopped

      __weel_sim_stop(:parallel,hw,pos) if __weel_sim

      cw = @__weel_connectionwrapper.new @__weel_connectionwrapper_args
      cw.join_branches(Thread.current[:branch_traces])

      unless self.__weel_state == :stopping || self.__weel_state == :finishing || self.__weel_state == :stopped
        # first set all to no_longer_neccessary
        Thread.current[:branches].each do |thread|
          if thread.alive?
            thread[:nolongernecessary] = true
            __weel_recursive_continue(thread)
          end
        end
        # wait for all
        Thread.current[:branches].each do |thread|
          __weel_recursive_join(thread)
        end
      end
    end # }}}

    # Defines a branch of a parallel-Construct
    def parallel_branch(*vars,&block)# {{{
      return if self.__weel_state == :stopping || self.__weel_state == :finishing || self.__weel_state == :stopped || Thread.current[:nolongernecessary]
      branch_parent = Thread.current

      if __weel_sim
        # catch the potential execution in loops inside a parallel
        current_branch_sim_pos = branch_parent[:branch_sim_pos]
      end

      branch_parent[:branches] << Thread.new(*vars) do |*local|
        Thread.current.abort_on_exception = true
        Thread.current[:branch_status] = false
        Thread.current[:branch_parent] = branch_parent
        Thread.current[:start_event] = Continue.new
        Thread.current[:local] = local
        Thread.current[:branch_wait_count_cancel_active] = false
        branch_parent[:mutex].synchronize do
          Thread.current[:branch_traces_id] = branch_parent[:branch_traces_ids]
          branch_parent[:branch_traces_ids] += 1
        end

        if __weel_sim
          Thread.current[:branch_sim_pos] = @__weel_sim += 1
        end

        # parallel_branch could be possibly around an alternative. Thus thread has to inherit the alternative_executed
        # after branching, update it in the parent (TODO)
        if branch_parent[:alternative_executed] && branch_parent[:alternative_executed].length > 0
          Thread.current[:alternative_executed] = [branch_parent[:alternative_executed].last]
          Thread.current[:alternative_mode] = [branch_parent[:alternative_mode].last]
        end
        branch_parent[:branch_event].continue
        Thread.current[:start_event].wait unless self.__weel_state == :stopping || self.__weel_state == :stopped || self.__weel_state == :finishing

        if __weel_sim
          connectionwrapper = @__weel_connectionwrapper.new @__weel_connectionwrapper_args
          connectionwrapper.simulate(:parallel_branch,:start,Thread.current[:branch_sim_pos],current_branch_sim_pos)
        end

        unless self.__weel_state == :stopping || self.__weel_state == :finishing || self.__weel_state == :stopped || Thread.current[:nolongernecessary]
          __weel_protect_yield(*local, &block)
        end

        __weel_sim_stop(:parallel_branch,connectionwrapper,current_branch_sim_pos) if __weel_sim

        branch_parent[:mutex].synchronize do
          Thread.current[:branch_status] = true
          branch_parent[:branch_finished_count] += 1
          if branch_parent[:branch_finished_count] == branch_parent[:branch_wait_count] && self.__weel_state != :stopping && self.__weel_state != :finishing
            branch_parent[:branch_event].continue
          end
        end
        unless self.__weel_state == :stopping || self.__weel_state == :stopped || self.__weel_state == :finishing
          if Thread.current[:branch_position]
            @__weel_positions.delete Thread.current[:branch_position]
            begin
              ipc = {}
              ipc[:unmark] = [Thread.current[:branch_position]]
              @__weel_connectionwrapper::inform_position_change(@__weel_connectionwrapper_args,ipc)
            end rescue nil
            Thread.current[:branch_position] = nil
          end
        end
      end
    end # }}}

    # Choose DSL-Construct
    # Defines a choice in the Workflow path.
    # May contain multiple execution alternatives
    def choose(mode=:inclusive,&block) # {{{
      return if self.__weel_state == :stopping || self.__weel_state == :finishing || self.__weel_state == :stopped || Thread.current[:nolongernecessary]
      Thread.current[:alternative_executed] ||= []
      Thread.current[:alternative_mode] ||= []
      Thread.current[:alternative_executed] << false
      Thread.current[:alternative_mode] << mode
      hw, pos = __weel_sim_start(:choose,:mode => Thread.current[:alternative_mode].last) if __weel_sim
      __weel_protect_yield(&block)
      __weel_sim_stop(:choose,hw,pos,:mode => Thread.current[:alternative_mode].last) if __weel_sim
      Thread.current[:alternative_executed].pop
      Thread.current[:alternative_mode].pop
      nil
    end # }}}

    # Defines a possible choice of a choose-Construct
    # Block is executed if condition == true or
    # searchmode is active (to find the starting position)
    def alternative(condition,args={},&block)# {{{
      return if self.__weel_state == :stopping || self.__weel_state == :finishing || self.__weel_state == :stopped || Thread.current[:nolongernecessary]
      hw, pos = __weel_sim_start(:alternative,args.merge(:mode => Thread.current[:alternative_mode].last, :condition => ((condition.is_a?(String) || condition.is_a?(Proc)) ? condition : nil))) if __weel_sim
      Thread.current[:mutex] ||= Mutex.new
      Thread.current[:mutex].synchronize do
        return if Thread.current[:alternative_mode][-1] == :exclusive && Thread.current[:alternative_executed][-1] == true
        if (condition.is_a?(String) || condition.is_a?(Proc)) && !__weel_sim
          condition = __weel_eval_condition(condition)
        end
        Thread.current[:alternative_executed][-1] = true if condition
      end
      __weel_protect_yield(&block) if __weel_is_in_search_mode || __weel_sim || condition
      __weel_sim_stop(:alternative,hw,pos,args.merge(:mode => Thread.current[:alternative_mode].last, :condition => ((condition.is_a?(String) || condition.is_a?(Proc)) ? condition : nil))) if __weel_sim
    end # }}}
    def otherwise(args={},&block) # {{{
      return if self.__weel_state == :stopping || self.__weel_state == :finishing || self.__weel_state == :stopped || Thread.current[:nolongernecessary]
      hw, pos = __weel_sim_start(:otherwise,args.merge(:mode => Thread.current[:alternative_mode].last)) if __weel_sim
      __weel_protect_yield(&block) if __weel_is_in_search_mode || __weel_sim || !Thread.current[:alternative_executed].last
      __weel_sim_stop(:otherwise,hw,pos,args.merge(:mode => Thread.current[:alternative_mode].last)) if __weel_sim
    end # }}}

    # Defines a critical block (=Mutex)
    def critical(id,&block)# {{{
      @__weel_critical ||= Mutex.new
      semaphore = nil
      @__weel_critical.synchronize do
        @__weel_critical_sections ||= {}
        semaphore = @__weel_critical_sections[id] ? @__weel_critical_sections[id] : Mutex.new
        @__weel_critical_sections[id] = semaphore if id
      end
      semaphore.synchronize do
        __weel_protect_yield(&block)
      end
    end # }}}

    # Defines a Cycle (loop/iteration)
    def loop(condition,args={},&block)# {{{
      unless condition.is_a?(Array) && (condition[0].is_a?(Proc) || condition[0].is_a?(String)) && [:pre_test,:post_test].include?(condition[1]) && args.is_a?(Hash)
        raise "condition must be called pre_test{} or post_test{}"
      end
      return if self.__weel_state == :stopping || self.__weel_state == :finishing || self.__weel_state == :stopped || Thread.current[:nolongernecessary]
      if __weel_is_in_search_mode
        catch :escape do
          __weel_protect_yield(&block)
        end
        if __weel_is_in_search_mode
          return
        else
          ### in case it was a :post_test we wake inside the loop so we can check
          ### condition first thing
          condition[1] = :pre_test
        end
      end
      if __weel_sim
        cond = condition[0].is_a?(Proc) ? true : condition[0]
        hw, pos = __weel_sim_start(:loop,args.merge(:testing=>condition[1],:condition=>cond))
        catch :escape do
          __weel_protect_yield(&block)
        end
        __weel_sim_stop(:loop,hw,pos,args.merge(:testing=>condition[1],:condition=>cond))
        return
      end
      loop_guard = 0
      loop_id = SecureRandom.uuid
      catch :escape do
        case condition[1]
          when :pre_test
            while __weel_eval_condition(condition[0]) && self.__weel_state != :stopping && self.__weel_state != :stopped && self.__weel_state != :finishing && !Thread.current[:nolongernecessary]
              loop_guard += 1
              __weel_protect_yield(&block)
              sleep 1 if @__weel_connectionwrapper::loop_guard(@__weel_connectionwrapper_args,loop_id,loop_guard)
            end
          when :post_test
            begin
              loop_guard += 1
              __weel_protect_yield(&block)
              sleep 1 if @__weel_connectionwrapper::loop_guard(@__weel_connectionwrapper_args,loop_id,loop_guard)
            end while __weel_eval_condition(condition[0]) && self.__weel_state != :stopping && self.__weel_state != :stopped && self.__weel_state != :finishing && !Thread.current[:nolongernecessary]
        end
      end
    end # }}}

    def test(code=nil,&blk)# {{{
      code || blk
    end # }}}
    def pre_test(code=nil,&blk)# {{{
      [code || blk, :pre_test]
    end # }}}
    def post_test(code=nil,&blk)# {{{
      [code || blk, :post_test]
    end # }}}

    def escape #{{{
      return if __weel_is_in_search_mode
      return if self.__weel_state == :stopping || self.__weel_state == :finishing || self.__weel_state == :stopped || Thread.current[:nolongernecessary]
      throw :escape
    end #}}}
    def terminate #{{{
      return if __weel_is_in_search_mode
      return if self.__weel_state == :stopping || self.__weel_state == :finishing || self.__weel_state == :stopped || Thread.current[:nolongernecessary]
      self.__weel_state = :finishing
    end #}}}
    def stop(position) #{{{
      searchmode = __weel_is_in_search_mode(position)
      return if searchmode
      return if self.__weel_state == :stopping || self.__weel_state == :finishing || self.__weel_state == :stopped || Thread.current[:nolongernecessary]

      # gather traces in threads to point to join
      if Thread.current[:branch_parent] && Thread.current[:branch_traces_id]
        Thread.current[:branch_parent][:branch_traces][Thread.current[:branch_traces_id]] ||= []
        Thread.current[:branch_parent][:branch_traces][Thread.current[:branch_traces_id]] << position
      end

      __weel_progress position, 0, true
      self.__weel_state = :stopping
    end #}}}

    def status # {{{
      @__weel_status
    end # }}}
    def data # {{{
      ReadOnlyHash.new(@__weel_data,__weel_sim)
    end # }}}
    def endpoints # {{{
      ReadHash.new(@__weel_endpoints)
    end # }}}

  private
    def __weel_protect_yield(*local) #{{{
      begin
        yield(*local) if block_given?
      rescue NameError => err # don't look into it, or it will explode
        self.__weel_state = :stopping
        @__weel_connectionwrapper::inform_syntax_error(@__weel_connectionwrapper_args,Exception.new("protect_yield: `#{err.name}` is not a thing that can be used. Maybe it is meant to be a string and you forgot quotes?"),nil)
        nil
      rescue => err
        self.__weel_state = :stopping
        @__weel_connectionwrapper::inform_syntax_error(@__weel_connectionwrapper_args,Exception.new(err.message),nil)
        nil
      end
    end #}}}

    def __weel_eval_condition(condition) #{{{
      begin
        connectionwrapper = @__weel_connectionwrapper.new @__weel_connectionwrapper_args unless condition.is_a?(Proc)
        condition.is_a?(Proc) ? condition.call : connectionwrapper.test_condition(ReadStructure.new(@__weel_data,@__weel_endpoints,Thread.current[:local],connectionwrapper.additional),condition)
      rescue NameError => err # don't look into it, or it will explode
        # if you access $! here, BOOOM
        self.__weel_state = :stopping
        @__weel_connectionwrapper::inform_syntax_error(@__weel_connectionwrapper_args,Exception.new("eval_condition: `#{err.name}` is not a thing that can be used. Maybe it is meant to be a string and you forgot quotes?"),nil)
        nil
      rescue => err
        self.__weel_state = :stopping
        @__weel_connectionwrapper::inform_syntax_error(@__weel_connectionwrapper_args,Exception.new(err.message),nil)
        nil
      end
    end #}}}

    def __weel_progress(position, uuid, skip=false) #{{{
      ipc = {}
      branch = Thread.current
      if Thread.current[:branch_parent] && Thread.current[:branch_parent][:branch_position]
        @__weel_positions.delete Thread.current[:branch_parent][:branch_position]
        ipc[:unmark] ||= []
        ipc[:unmark] << Thread.current[:branch_parent][:branch_position] rescue nil
        Thread.current[:branch_parent][:branch_position] = nil
      end
      if Thread.current[:branch_position]
        @__weel_positions.delete Thread.current[:branch_position]
        ipc[:unmark] ||= []
        ipc[:unmark] << Thread.current[:branch_position] rescue nil
      end
      wp = if branch[:branch_search_now] == true
        branch[:branch_search_now] = false
        WEEL::Position.new(position, uuid, skip ? :after : :at, @__weel_search_positions[position]&.passthrough)
      else
        WEEL::Position.new(position, uuid, skip ? :after : :at)
      end
      ipc[skip ? :after : :at] = [wp]

      @__weel_search_positions.delete(position)
      @__weel_search_positions.each do |k,ele| # some may still be in active search but lets unmark them for good measure
        ipc[:unmark] ||= []
        ipc[:unmark] << ele
        true
      end
      ipc[:unmark].uniq! if ipc[:unmark]

      @__weel_positions << wp
      Thread.current[:branch_position] = wp

      @__weel_connectionwrapper::inform_position_change @__weel_connectionwrapper_args, ipc
      wp
    end #}}}

    def __weel_activity(position, type, endpoint, parameters, finalize=nil, update=nil, prepare=nil, salvage=nil)# {{{
      position = __weel_position_test position
      begin
        searchmode = __weel_is_in_search_mode(position)
        return if searchmode == true
        return if self.__weel_state == :stopping || self.__weel_state == :finishing || self.__weel_state == :stopped || Thread.current[:nolongernecessary]

        Thread.current[:continue] = Continue.new
        connectionwrapper = @__weel_connectionwrapper.new @__weel_connectionwrapper_args, position, Thread.current[:continue]

        if __weel_sim
          connectionwrapper.simulate(:activity,:none,@__weel_sim += 1,Thread.current[:branch_sim_pos],:position => position,:parameters => parameters,:endpoint => endpoint,:type => type,:finalize => finalize.is_a?(String) ? finalize : nil)
          return
        end

        # gather traces in threads to point to join
        if Thread.current[:branch_parent] && Thread.current[:branch_traces_id]
          Thread.current[:branch_parent][:branch_traces][Thread.current[:branch_traces_id]] ||= []
          Thread.current[:branch_parent][:branch_traces][Thread.current[:branch_traces_id]] << position
        end

        wp = __weel_progress position, connectionwrapper.activity_uuid

        # searchmode position is after, jump directly to vote_sync_after
        raise Signal::Proceed if searchmode == :after

        case type
          when :manipulate
            raise Signal::Stop unless connectionwrapper.vote_sync_before
            raise Signal::Skip if self.__weel_state == :stopping || self.__weel_state == :finishing

            if finalize.is_a?(Proc) || finalize.is_a?(String)
              connectionwrapper.activity_manipulate_handle(parameters)
              connectionwrapper.inform_activity_manipulate
              if finalize.is_a?(Proc)
                mr = ManipulateStructure.new(@__weel_data,@__weel_endpoints,@__weel_status,Thread.current[:local],connectionwrapper.additional)
                mr.instance_eval(&finalize)
              elsif finalize.is_a?(String)
                mr = ManipulateStructure.new(@__weel_data,@__weel_endpoints,@__weel_status,Thread.current[:local],connectionwrapper.additional)
                connectionwrapper.manipulate(mr,finalize,'Activity ' + position.to_s)
              end
              connectionwrapper.inform_manipulate_change(
                ((mr && mr.changed_status) ? @__weel_status : nil),
                ((mr && mr.changed_data.any?) ? mr.changed_data.uniq : nil),
                ((mr && mr.changed_endpoints.any?) ? mr.changed_endpoints.uniq : nil),
                @__weel_data,
                @__weel_endpoints
              )
              connectionwrapper.inform_activity_done
              wp.detail = :after
              @__weel_connectionwrapper::inform_position_change @__weel_connectionwrapper_args, :after => [wp]
            end
          when :call
            begin
              again = catch Signal::Again do
                connectionwrapper.mem_guard
                rs = ReadStructure.new(@__weel_data,@__weel_endpoints,Thread.current[:local],connectionwrapper.additional)
                if prepare
                  if prepare.is_a?(Proc)
                    rs.instance_exec(&prepare)
                  elsif prepare.is_a?(String)
                    connectionwrapper.manipulate(rs,prepare,'Activity ' + position.to_s)
                  end
                end
                params = connectionwrapper.prepare(rs,endpoint,parameters,@__weel_replay)
                raise Signal::Stop unless connectionwrapper.vote_sync_before(params)
                raise Signal::Skip if self.__weel_state == :stopping || self.__weel_state == :finishing

                connectionwrapper.activity_handle wp.passthrough, params
                wp.passthrough = connectionwrapper.activity_passthrough_value
                unless wp.passthrough.nil?
                  @__weel_connectionwrapper::inform_position_change @__weel_connectionwrapper_args, :wait => [wp]
                end
                begin
                  # with loop if catching Signal::Again
                  # handshake call and wait until it finished
                  waitingresult = nil
                  waitingresult = Thread.current[:continue].wait unless Thread.current[:nolongernecessary] || self.__weel_state == :stopping || self.__weel_state == :finishing || self.__weel_state == :stopped
                  raise waitingresult[1] if !waitingresult.nil? && waitingresult.is_a?(Array) && waitingresult.length == 2 && waitingresult[0] == WEEL::Signal::Error

                  if Thread.current[:nolongernecessary]
                    connectionwrapper.activity_no_longer_necessary
                    raise Signal::NoLongerNecessary
                  end
                  if self.__weel_state == :stopping || self.__weel_state == :finishing
                    connectionwrapper.activity_stop
                    wp.passthrough = connectionwrapper.activity_passthrough_value
                    raise Signal::Proceed if wp.passthrough # if stop, but no passthrough, let manipulate happen and then stop
                  end

                  code = if waitingresult == WEEL::Signal::Again
                    update
                  elsif waitingresult == WEEL::Signal::Salvage
                    salvage || raise('HTTP Error. The service return status was not between 200 and 300.')
                  else
                    finalize
                  end
                  if code.is_a?(Proc) || code.is_a?(String)
                    connectionwrapper.inform_activity_manipulate
                    if code.is_a?(Proc)
                      mr = ManipulateStructure.new(@__weel_data,@__weel_endpoints,@__weel_status,Thread.current[:local],connectionwrapper.additional)
                      ma = catch Signal::Again do
                        case code.arity
                          when 1; mr.instance_exec(connectionwrapper.activity_result_value,&code)
                          when 2; mr.instance_exec(connectionwrapper.activity_result_value,&code)
                          else
                            mr.instance_exec(&code)
                        end
                        'yes' # ma sadly will have nil when i just throw
                      end
                    elsif code.is_a?(String)
                      mr = ManipulateStructure.new(@__weel_data,@__weel_endpoints,@__weel_status,Thread.current[:local],connectionwrapper.additional)
                      ma = catch Signal::Again do
                        connectionwrapper.manipulate(mr,code,'Activity ' + position.to_s,connectionwrapper.activity_result_value,connectionwrapper.activity_result_options)
                        'yes' # ma sadly will have nil when i just throw
                      end
                    end
                    connectionwrapper.inform_manipulate_change(
                      (mr.changed_status ? @__weel_status : nil),
                      (mr.changed_data.any? ? mr.changed_data.uniq : nil),
                      (mr.changed_endpoints.any? ? mr.changed_endpoints.uniq : nil),
                      @__weel_data,
                      @__weel_endpoints
                    )
                    throw(Signal::Again, Signal::Again) if ma.nil?
                  end
                end while waitingresult == Signal::Again
                if connectionwrapper.activity_passthrough_value.nil?
                  connectionwrapper.inform_activity_done
                  wp.passthrough = nil
                  wp.detail = :after
                  @__weel_connectionwrapper::inform_position_change @__weel_connectionwrapper_args, :after => [wp]
                end
              end
            end while again == Signal::Again
        end
        raise Signal::Proceed
      rescue Signal::SkipManipulate, Signal::Proceed
        if self.__weel_state != :stopping && self.__weel_state != :finishing && !connectionwrapper.vote_sync_after
          self.__weel_state = :stopping
          wp.detail = :unmark
        end
      rescue Signal::NoLongerNecessary
        @__weel_positions.delete wp
        Thread.current[:branch_position] = nil
        wp.detail = :unmark
        @__weel_connectionwrapper::inform_position_change @__weel_connectionwrapper_args, :unmark => [wp]
      rescue Signal::StopSkipManipulate, Signal::Stop
        self.__weel_state = :stopping
      rescue Signal::Skip
        nil
      rescue SyntaxError => se
        connectionwrapper.inform_activity_failed se
        self.__weel_state = :stopping
      rescue => err
        @__weel_connectionwrapper::inform_connectionwrapper_error @__weel_connectionwrapper_args, err
        self.__weel_state = :stopping
      ensure
        connectionwrapper.mem_guard unless connectionwrapper.nil?
        if Thread.current[:branch_parent]
          Thread.current[:branch_parent][:mutex].synchronize do
            if Thread.current[:branch_parent][:branch_wait_count_cancel_condition] == :first
              if !Thread.current[:branch_wait_count_cancel_active]
                Thread.current[:branch_wait_count_cancel_active] = true
                Thread.current[:branch_parent][:branch_wait_count_cancel] += 1
              end
              if Thread.current[:branch_parent][:branch_wait_count_cancel] ==  Thread.current[:branch_parent][:branch_wait_count]  && self.__weel_state != :stopping && self.__weel_state != :finishing
                Thread.current[:branch_parent][:branches].each do |thread|
                  if thread.alive? && thread != Thread.current
                    thread[:nolongernecessary] = true
                    __weel_recursive_continue(thread)
                  end
                end
              end
            end
          end
        end
        Thread.current[:continue].clear if Thread.current[:continue] && Thread.current[:continue].is_a?(Continue)
      end
    end # }}}

    def __weel_recursive_print(thread,indent='')# {{{
      p "#{indent}#{thread}"
      if thread[:branches]
        thread[:branches].each do |b|
          __weel_recursive_print(b,indent+'  ')
        end
      end
    end  # }}}
    def __weel_recursive_continue(thread)# {{{
      return unless thread
      if thread.alive? && thread[:continue]
        thread[:continue].continue
      end
      if thread.alive? && thread[:branch_event]
        thread[:mutex].synchronize do
          thread[:branch_event].continue unless thread[:branch_event].nil?
        end
      end
      if thread[:branches]
        thread[:branches].each do |b|
          __weel_recursive_continue(b)
        end
      end
    end  # }}}
    def __weel_recursive_join(thread)# {{{
      return unless thread
      if thread.alive? && thread != Thread.current
        thread.join
      end
      if thread[:branches]
        thread[:branches].each do |b|
          __weel_recursive_join(b)
        end
      end
    end  # }}}

    def __weel_position_test(position)# {{{
      if position.is_a?(Symbol) && position.to_s =~ /[a-zA-Z][a-zA-Z0-9_]*/
        position
      else
        self.__weel_state = :stopping
        @__weel_connectionwrapper::inform_syntax_error(@__weel_connectionwrapper_args,Exception.new("position (#{position}) not valid"),nil)
      end
    end # }}}

    def __weel_is_in_search_mode(position = nil)# {{{
      branch = Thread.current
      return false if @__weel_search_positions.empty? || branch[:branch_search] == false

      if position && @__weel_search_positions.include?(position) # matching searchpos => start execution from here
        branch[:branch_search] = false # execute all activities in THIS branch (thread) after this point
        branch[:branch_search_now] = true # just now did we switch the search mode
        while branch.key?(:branch_parent) # also all parent branches should execute activities after this point, additional branches spawned by parent branches should still be in search mode
          branch = branch[:branch_parent]
          branch[:branch_search] = false
          branch[:branch_search_now] = true # just now did we switch the search mode
        end
        @__weel_search_positions[position].detail == :after
      else
        branch[:branch_search] = true
      end
    end # }}}

    def __weel_sim #{{{
      @__weel_state == :simulating
    end #}}}

    def __weel_sim_start(what,options={}) #{{{
      current_branch_sim_pos = Thread.current[:branch_sim_pos]
      Thread.current[:branch_sim_pos] = @__weel_sim += 1
      connectionwrapper = @__weel_connectionwrapper.new @__weel_connectionwrapper_args
      connectionwrapper.simulate(what,:start,Thread.current[:branch_sim_pos],current_branch_sim_pos,options)
      [connectionwrapper, current_branch_sim_pos]
    end #}}}

    def __weel_sim_stop(what,connectionwrapper,current_branch_sim_pos,options={}) #{{{
      connectionwrapper.simulate(what,:end,Thread.current[:branch_sim_pos],current_branch_sim_pos,options)
      Thread.current[:branch_sim_pos] = current_branch_sim_pos
    end #}}}

  public
    def __weel_finalize #{{{
      __weel_recursive_join(@__weel_main)
      @__weel_state = :stopped
      @__weel_connectionwrapper::inform_state_change @__weel_connectionwrapper_args, @__weel_state
    end #}}}

    def __weel_state=(newState)# {{{
      return @__weel_state if newState == @__weel_state && @__weel_state != :ready

      @__weel_positions = Array.new if newState == :running
      @__weel_state = newState

      if newState == :stopping || newState == :finishing
        @__weel_status.nudge!
        __weel_recursive_continue(@__weel_main)
        __weel_replay = false
      end

      @__weel_connectionwrapper::inform_state_change @__weel_connectionwrapper_args, @__weel_state
    end # }}}

  end # }}}

public
  def positions # {{{
    @dslr.__weel_positions
  end # }}}

  # set the connectionwrapper
  def connectionwrapper # {{{
    @dslr.__weel_connectionwrapper
  end # }}}
  def connectionwrapper=(new_weel_connectionwrapper) # {{{
    superclass = new_weel_connectionwrapper
    while superclass
      check_ok = true if superclass == WEEL::ConnectionWrapperBase
      superclass = superclass.superclass
    end
    raise "ConnectionWrapper is not inherited from ConnectionWrapperBase" unless check_ok
    @dslr.__weel_connectionwrapper = new_weel_connectionwrapper
  end # }}}

  # Get/Set the connectionwrapper arguments
  def connectionwrapper_args # {{{
    @dslr.__weel_connectionwrapper_args
  end # }}}
  def connectionwrapper_args=(args) # {{{
    if args.class == Array
      @dslr.__weel_connectionwrapper_args = args
    end
    nil
  end #  }}}

  # Get the state of execution (ready|running|stopping|stopped|finished|simulating|abandoned)
  def state # {{{
    @dslr.__weel_state
  end #  }}}
  def state_signal # {{{
    connectionwrapper::inform_state_change connectionwrapper_args, state
    state
  end # }}}
  def abandon # {{{
    @dslr.__weel_state = :abandoned
  end # }}}

  # Set search positions
  # set new_weel_search to a boolean (or anything else) to start the process from beginning (reset serach positions)
  def search(new_weel_search=false) # {{{
    @dslr.__weel_search_positions.clear

    new_weel_search = [new_weel_search] if new_weel_search.is_a?(Position)

    if !new_weel_search.is_a?(Array) || new_weel_search.empty?
      false
    else
      new_weel_search.each do |search_position|
        @dslr.__weel_search_positions[search_position.position] = search_position
      end
      true
    end
  end # }}}

  def data(new_data=nil) # {{{
    unless new_data.nil? || !new_data.is_a?(Hash)
      new_data.each{ |k,v| @dslr.__weel_data[k] = v }
    end
    @dslr.__weel_data
  end # }}}
  def endpoints(new_endpoints=nil) # {{{
    unless new_endpoints.nil? || !new_endpoints.is_a?(Hash)
      new_endpoints.each{ |k,v| @dslr.__weel_endpoints[k] = v }
    end
    @dslr.__weel_endpoints
  end # }}}
  def endpoint(new_endpoints) # {{{
    unless new_endpoints.nil? || !new_endpoints.is_a?(Hash) || !new_endpoints.length == 1
      new_endpoints.each{ |k,v| @dslr.__weel_endpoints[k] = v }
    end
    nil
  end # }}}
  def status # {{{
    @dslr.__weel_status
  end # }}}

  # get/set workflow description
  def description(&blk)
    self.description=(blk)
  end
  def description=(code) # {{{
    (class << self; self; end).class_eval do
      remove_method :__weel_control_flow if method_defined? :__weel_control_flow
      define_method :__weel_control_flow do |state,final_state=:finished|
        @dslr.__weel_positions.clear
        @dslr.__weel_state = state
        begin
          if code.is_a? Proc
            @dslr.instance_eval(&code)
          else
            @dslr.instance_eval(code)
          end
        rescue SyntaxError => se
          @dslr.__weel_state = :stopping
          @dslr.__weel_connectionwrapper::inform_syntax_error(@dslr.__weel_connectionwrapper_args,Exception.new(se.message),code)
        rescue NameError => err # don't look into it, or it will explode
          @dslr.__weel_state = :stopping
          @dslr.__weel_connectionwrapper::inform_syntax_error(@dslr.__weel_connectionwrapper_args,Exception.new("main: `#{err.name}` is not a thing that can be used. Maybe it is meant to be a string and you forgot quotes?"),code)
        rescue => err
          @dslr.__weel_state = :stopping
          @dslr.__weel_connectionwrapper::inform_syntax_error(@dslr.__weel_connectionwrapper_args,Exception.new(err.message),code)
        end
        if @dslr.__weel_state == :running || @dslr.__weel_state == :finishing
          ipc = { :unmark => [] }
          @dslr.__weel_positions.each{ |wp| ipc[:unmark] << wp }
          @dslr.__weel_positions.clear
          @dslr.__weel_connectionwrapper::inform_position_change(@dslr.__weel_connectionwrapper_args,ipc)
          @dslr.__weel_state = :finished
        end
        if @dslr.__weel_state == :simulating
          @dslr.__weel_state = final_state
        end
        if @dslr.__weel_state == :stopping
          @dslr.__weel_finalize
        end
      end
    end
  end # }}}

  # Stop the workflow execution
  def stop # {{{
    Thread.new do
      if  @dslr.__weel_state == :running
        @dslr.__weel_state = :stopping
        @dslr.__weel_main.join if @dslr.__weel_main
      elsif @dslr.__weel_state == :ready || @dslr.__weel_state == :stopped
        @dslr.__weel_state = :stopped
      end
    end
  end # }}}
  # Start the workflow execution
  def start # {{{
    return nil if @dslr.__weel_state != :ready && @dslr.__weel_state != :stopped
    @dslr.__weel_main = Thread.new do
      begin
        __weel_control_flow(:running)
      rescue => e
        puts e.message
        puts e.backtrace
        connectionwrapper::inform_connectionwrapper_error connectionwrapper_args, e
      end
    end
  end # }}}

  def replay
    @dslr.__weel_replay = true
    start
  end

  def sim # {{{
    stat = @dslr.__weel_state
    return nil unless stat == :ready || stat == :stopped
    @dslr.__weel_main = Thread.new do
      __weel_control_flow :simulating, stat
    end
  end # }}}

end

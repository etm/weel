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

# OMG!111! deep cloning for ReadHashes
class Object # {{{
  def deep_clone
    return @deep_cloning_obj if @deep_cloning
    @deep_cloning_obj = clone
    @deep_cloning_obj.instance_variables.each do |var|
      val = @deep_cloning_obj.instance_variable_get(var)
      begin
        @deep_cloning = true
        val = val.deep_clone
      rescue TypeError
        next
      ensure
        @deep_cloning = false
      end
      @deep_cloning_obj.instance_variable_set(var, val)
    end
    deep_cloning_obj = @deep_cloning_obj
    @deep_cloning_obj = nil
    deep_cloning_obj
  end
end #}}}

class WEEL
  def initialize(*args)# {{{
    @dslr = DSLRealization.new
    @dslr.__weel_handlerwrapper_args = args

    initialize_search if methods.include?(:initialize_search)
    initialize_data if methods.include?(:initialize_data)
    initialize_endpoints if methods.include?(:initialize_endpoints)
    initialize_handlerwrapper if methods.include?(:initialize_handlerwrapper)
    initialize_control if methods.include?(:initialize_control)
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
  end # }}}

  class ReadStructure # {{{
    def initialize(data,endpoints)
      @__weel_data = data
      @__weel_endpoints = endpoints
      @changed_data = []
      @changed_endpoints = []
    end

    def data
      ReadHash.new(@__weel_data)
    end
    def endpoints
      ReadHash.new(@__weel_endpoints)
    end
  end # }}}
  class ManipulateStructure # {{{
    def initialize(data,endpoints,status)
      @__weel_data = data
      @__weel_data_orig = @__weel_data.transform_values{|val| Marshal.dump(val) }
      @__weel_endpoints = endpoints
      @__weel_endpoints_orig = @__weel_endpoints.transform_values{|val| Marshal.dump(val) }
      @__weel_status = status
      @changed_status = "#{status.id}-#{status.message}"
      @changed_data = []
      @touched_data = []
      @changed_endpoints = []
      @touched_endpoints = []
    end

    def changed_data
      @touched_data.each do |e|
        if Marshal.dump(@__weel_data[e]) != @__weel_data_orig[e]
          @changed_data << e
        end
      end
      @changed_data
    end
    def changed_endpoints
      @changed_endpoints
    end

    def original_data
      @__weel_data_orig.transform_values{|val| Marshal.load(val) }
    end

    def original_endpoints
      @__weel_endpoints_orig.transform_values{|val| Marshal.load(val) }
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
      @nudge.clear
      @nudge.push(nil)
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
      if args.empty? && @__weel_values.key?(name)
        if @__weel_sim
          "➤#{name}"
        else
          @__weel_values[name]
        end
        #TODO dont let user change stuff e.g. if return value is an array (deep clone and/or deep freeze it?)
      else
        nil
      end
    end
  end # }}}

  class HandlerWrapperBase # {{{
    def self::inform_state_change(arguments,newstate); end
    def self::inform_syntax_error(arguments,err,code); end
    def self::inform_handlerwrapper_error(arguments,err); end
    def self::inform_position_change(arguments,ipc); end

    def initialize(arguments,endpoint=nil,position=nil,continue=nil); end

    def activity_handle(passthrough, parameters); end
    def activity_manipulate_handle(parameters); end

    def activity_result_value; end

    def activity_stop; end
    def activity_passthrough_value; end

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

    def test_condition(mr,code); mr.instance_eval(code); end
    def manipulate(mr,code,result=nil); mr.instance_eval(code); end
  end  # }}}

  class Position # {{{
    attr_reader :position
    attr_accessor :detail, :passthrough
    def initialize(position, detail=:at, passthrough=nil) # :at or :after or :unmark
      @position = position
      @detail = detail
      @passthrough = passthrough
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

  def self::search(weel_search)# {{{
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
  def self::handlerwrapper(aClassname, *args)# {{{
    define_method :initialize_handlerwrapper do
      self.handlerwrapper = aClassname
      self.handlerwrapper_args = args unless args.empty?
    end
  end # }}}
  def self::control(flow, &block)# {{{
    @@__weel_control_block = block
    define_method :initialize_control do
      self.description = @@__weel_control_block
    end
  end #  }}}
  def self::flow # {{{
  end #}}}

  class DSLRealization # {{{
    def  initialize #{{{
      @__weel_search_positions = {}
      @__weel_positions = Array.new
      @__weel_main = nil
      @__weel_data ||= Hash.new
      @__weel_endpoints ||= Hash.new
      @__weel_handlerwrapper = HandlerWrapperBase
      @__weel_handlerwrapper_args = []
      @__weel_state = :ready
      @__weel_status = Status.new(0,"undefined")
      @__weel_sim = -1
    end #}}}
    attr_accessor :__weel_search_positions, :__weel_positions, :__weel_main, :__weel_data, :__weel_endpoints, :__weel_handlerwrapper, :__weel_handlerwrapper_args
    attr_reader :__weel_state, :__weel_status

    # DSL-Constructs for atomic calls to external services (calls) and pure context manipulations (manipulate).
    # Calls can also manipulate context (after the invoking the external services)
    # position: a unique identifier within the wf-description (may be used by the search to identify a starting point)
    # endpoint: (only with :call) ep of the service
    # parameters: (only with :call) service parameters
    def call(position, endpoint, parameters: {}, finalize: nil, update: nil, &finalizeblk) #{{{
      __weel_activity(position,:call,endpoint,parameters,finalize||finalizeblk,update)
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
    def parallel(type=nil)# {{{
      return if self.__weel_state == :stopping || self.__weel_state == :finishing || self.__weel_state == :stopped || Thread.current[:nolongernecessary]

      Thread.current[:branches] = []
      Thread.current[:branch_finished_count] = 0
      Thread.current[:branch_event] = Continue.new
      Thread.current[:mutex] = Mutex.new

      hw, pos = __weel_sim_start(:parallel) if __weel_sim

      __weel_protect_yield(&Proc.new)

      Thread.current[:branch_wait_count] = (type.is_a?(Hash) && type.size == 1 && type[:wait] != nil && (type[:wait].is_a?(Integer) && type[:wait] > 0) ? type[:wait] : Thread.current[:branches].size)
      1.upto Thread.current[:branches].size do
        Thread.current[:branch_event].wait
      end

      Thread.current[:branches].each do |thread|
        # decide after executing block in parallel cause for coopis
        # it goes out of search mode while dynamically counting branches
        if Thread.current[:branch_search] == false
          thread[:branch_search] = false
        end
        thread[:start_event].continue
      end

      Thread.current[:branch_event].wait

      __weel_sim_stop(:parallel,hw,pos) if __weel_sim

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
    def parallel_branch(*vars)# {{{
      return if self.__weel_state == :stopping || self.__weel_state == :finishing || self.__weel_state == :stopped || Thread.current[:nolongernecessary]
      branch_parent = Thread.current

      if __weel_sim
        # catch the potential execution in loops inside a parallel
        current_branch_sim_pos = branch_parent[:branch_sim_pos]
      end

      Thread.current[:branches] << Thread.new(*vars) do |*local|
        Thread.current.abort_on_exception = true
        Thread.current[:branch_status] = false
        Thread.current[:branch_parent] = branch_parent
        Thread.current[:start_event] = Continue.new

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
        Thread.current[:start_event].wait

        if __weel_sim
          handlerwrapper = @__weel_handlerwrapper.new @__weel_handlerwrapper_args
          handlerwrapper.simulate(:parallel_branch,:start,Thread.current[:branch_sim_pos],current_branch_sim_pos)
        end

        __weel_protect_yield(*local, &Proc.new)

        __weel_sim_stop(:parallel_branch,handlerwrapper,current_branch_sim_pos) if __weel_sim

        branch_parent[:mutex].synchronize do
          Thread.current[:branch_status] = true
          branch_parent[:branch_finished_count] += 1
          if branch_parent[:branch_finished_count] == branch_parent[:branch_wait_count] && self.__weel_state != :stopping && self.__weel_state != :finishing
            branch_parent[:branch_event].continue
          end
        end
        if self.__weel_state != :stopping && self.__weel_state != :stopped && self.__weel_state != :finishing
          if Thread.current[:branch_position]
            @__weel_positions.delete Thread.current[:branch_position]
            begin
              ipc = {}
              ipc[:unmark] = [Thread.current[:branch_position].position]
              @__weel_handlerwrapper::inform_position_change(@__weel_handlerwrapper_args,ipc)
            end rescue nil
            Thread.current[:branch_position] = nil
          end
        end
      end
    end # }}}

    # Choose DSL-Construct
    # Defines a choice in the Workflow path.
    # May contain multiple execution alternatives
    def choose(mode=:inclusive) # {{{
      return if self.__weel_state == :stopping || self.__weel_state == :finishing || self.__weel_state == :stopped || Thread.current[:nolongernecessary]
      Thread.current[:alternative_executed] ||= []
      Thread.current[:alternative_mode] ||= []
      Thread.current[:alternative_executed] << false
      Thread.current[:alternative_mode] << mode
      hw, pos = __weel_sim_start(:choose,:mode => Thread.current[:alternative_mode].last) if __weel_sim
      __weel_protect_yield(&Proc.new)
      __weel_sim_stop(:choose,hw,pos,:mode => Thread.current[:alternative_mode].last) if __weel_sim
      Thread.current[:alternative_executed].pop
      Thread.current[:alternative_mode].pop
      nil
    end # }}}

    # Defines a possible choice of a choose-Construct
    # Block is executed if condition == true or
    # searchmode is active (to find the starting position)
    def alternative(condition,args={})# {{{
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
      __weel_protect_yield(&Proc.new) if __weel_is_in_search_mode || __weel_sim || condition
      __weel_sim_stop(:alternative,hw,pos,args.merge(:mode => Thread.current[:alternative_mode].last, :condition => ((condition.is_a?(String) || condition.is_a?(Proc)) ? condition : nil))) if __weel_sim
    end # }}}
    def otherwise(args={}) # {{{
      return if self.__weel_state == :stopping || self.__weel_state == :finishing || self.__weel_state == :stopped || Thread.current[:nolongernecessary]
      hw, pos = __weel_sim_start(:otherwise,args.merge(:mode => Thread.current[:alternative_mode].last)) if __weel_sim
      __weel_protect_yield(&Proc.new) if __weel_is_in_search_mode || __weel_sim || !Thread.current[:alternative_executed].last
      __weel_sim_stop(:otherwise,hw,pos,args.merge(:mode => Thread.current[:alternative_mode].last)) if __weel_sim
    end # }}}

    # Defines a critical block (=Mutex)
    def critical(id)# {{{
      @__weel_critical ||= Mutex.new
      semaphore = nil
      @__weel_critical.synchronize do
        @__weel_critical_sections ||= {}
        semaphore = @__weel_critical_sections[id] ? @__weel_critical_sections[id] : Mutex.new
        @__weel_critical_sections[id] = semaphore if id
      end
      semaphore.synchronize do
        __weel_protect_yield(&Proc.new)
      end
    end # }}}

    # Defines a Cycle (loop/iteration)
    def loop(condition,args={})# {{{
      unless condition.is_a?(Array) && (condition[0].is_a?(Proc) || condition[0].is_a?(String)) && [:pre_test,:post_test].include?(condition[1]) && args.is_a?(Hash)
        raise "condition must be called pre_test{} or post_test{}"
      end
      return if self.__weel_state == :stopping || self.__weel_state == :finishing || self.__weel_state == :stopped || Thread.current[:nolongernecessary]
      if __weel_is_in_search_mode
        catch :escape do
          __weel_protect_yield(&Proc.new)
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
          __weel_protect_yield(&Proc.new)
        end
        __weel_sim_stop(:loop,hw,pos,args.merge(:testing=>condition[1],:condition=>cond))
        return
      end
      catch :escape do
        case condition[1]
          when :pre_test
            while __weel_eval_condition(condition[0]) && self.__weel_state != :stopping && self.__weel_state != :stopped && self.__weel_state != :finishing
              __weel_protect_yield(&Proc.new)
            end
          when :post_test
            begin
              __weel_protect_yield(&Proc.new)
            end while __weel_eval_condition(condition[0]) && self.__weel_state != :stopping && self.__weel_state != :stopped && self.__weel_state != :finishing
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
      throw :escape
    end #}}}
    def terminate #{{{
      return if __weel_is_in_search_mode
      self.__weel_state = :finishing
    end #}}}
    def stop(position) #{{{
      searchmode = __weel_is_in_search_mode(position)
      return if searchmode
      __weel_progress searchmode, position, true
      self.__weel_state = :stopping
    end #}}}

    def status # {{{
      @__weel_status
    end # }}}
    def data # {{{
      ReadHash.new(@__weel_data,__weel_sim)
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
        @__weel_handlerwrapper::inform_syntax_error(@__weel_handlerwrapper_args,Exception.new("protect_yield: `#{err.name}` is not a thing that can be used. Maybe it is meant to be a string and you forgot quotes?"),nil)
        nil
      rescue => err
        self.__weel_state = :stopping
        @__weel_handlerwrapper::inform_syntax_error(@__weel_handlerwrapper_args,Exception.new(err.message),nil)
        nil
      end
    end #}}}

    def __weel_eval_condition(condition) #{{{
      begin
        handlerwrapper = @__weel_handlerwrapper.new @__weel_handlerwrapper_args unless condition.is_a?(Proc)
        condition.is_a?(Proc) ? condition.call : handlerwrapper.test_condition(ReadStructure.new(@__weel_data,@__weel_endpoints),condition)
      rescue NameError => err # don't look into it, or it will explode
        # if you access $! here, BOOOM
        self.__weel_state = :stopping
        @__weel_handlerwrapper::inform_syntax_error(@__weel_handlerwrapper_args,Exception.new("eval_condition: `#{err.name}` is not a thing that can be used. Maybe it is meant to be a string and you forgot quotes?"),nil)
        nil
      rescue => err
        self.__weel_state = :stopping
        @__weel_handlerwrapper::inform_syntax_error(@__weel_handlerwrapper_args,Exception.new(err.message),nil)
        nil
      end
    end #}}}

    def __weel_progress(searchmode, position, skip=false) #{{{
      ipc = {}
      if searchmode == :after
        wp = WEEL::Position.new(position, :after, nil)
        ipc[:after] = [wp.position]
      else
        if Thread.current[:branch_parent] && Thread.current[:branch_parent][:branch_position]
          @__weel_positions.delete Thread.current[:branch_parent][:branch_position]
          ipc[:unmark] ||= []
          ipc[:unmark] << Thread.current[:branch_parent][:branch_position].position rescue nil
          Thread.current[:branch_parent][:branch_position] = nil
        end
        if Thread.current[:branch_position]
          @__weel_positions.delete Thread.current[:branch_position]
          ipc[:unmark] ||= []
          ipc[:unmark] << Thread.current[:branch_position].position rescue nil
        end
        wp = WEEL::Position.new(position, skip ? :after : :at, nil)
        ipc[skip ? :after : :at] = [wp.position]
      end
      @__weel_positions << wp
      Thread.current[:branch_position] = wp

      @__weel_handlerwrapper::inform_position_change @__weel_handlerwrapper_args, ipc
      wp
    end #}}}

    def __weel_activity(position, type, endpoints, parameters, finalize, update=nil)# {{{
      position = __weel_position_test position
      begin
        searchmode = __weel_is_in_search_mode(position)
        return if searchmode == true
        return if self.__weel_state == :stopping || self.__weel_state == :finishing || self.__weel_state == :stopped || Thread.current[:nolongernecessary]

        Thread.current[:continue] = Continue.new
        handlerwrapper = @__weel_handlerwrapper.new @__weel_handlerwrapper_args, endpoints.is_a?(Array) ? endpoints.map{ |ep| @__weel_endpoints[ep] }.compact : @__weel_endpoints[endpoints], position, Thread.current[:continue]

        if __weel_sim
          handlerwrapper.simulate(:activity,:none,@__weel_sim += 1,Thread.current[:branch_sim_pos],:position => position,:parameters => parameters,:endpoints => endpoints,:type => type,:finalize => finalize.is_a?(String) ? finalize : nil)
          return
        end

        wp = __weel_progress searchmode, position

        # searchmode position is after, jump directly to vote_sync_after
        raise Signal::Proceed if searchmode == :after

        case type
          when :manipulate
            raise Signal::Stop unless handlerwrapper.vote_sync_before
            raise Signal::Skip if self.__weel_state == :stopping || self.__weel_state == :finishing

            if finalize.is_a?(Proc) || finalize.is_a?(String)
              handlerwrapper.activity_manipulate_handle(parameters)
              handlerwrapper.inform_activity_manipulate
              if finalize.is_a?(Proc)
                mr = ManipulateStructure.new(@__weel_data,@__weel_endpoints,@__weel_status)
                mr.instance_eval(&finalize)
              elsif finalize.is_a?(String)
                mr = ManipulateStructure.new(@__weel_data,@__weel_endpoints,@__weel_status)
                handlerwrapper.manipulate(mr,finalize)
              end
              handlerwrapper.inform_manipulate_change(
                ((mr && mr.changed_status) ? @__weel_status : nil),
                ((mr && mr.changed_data.any?) ? mr.changed_data.uniq : nil),
                ((mr && mr.changed_endpoints.any?) ? mr.changed_endpoints.uniq : nil),
                @__weel_data,
                @__weel_endpoints
              )
              handlerwrapper.inform_activity_done
              wp.detail = :after
              @__weel_handlerwrapper::inform_position_change @__weel_handlerwrapper_args, :after => [wp.position]
            end
          when :call
            params = { }
            case parameters
              when Hash
                parameters.each do |k,p|
                  if p.is_a?(Symbol) && @__weel_data.include?(p)
                    params[k] = @__weel_data[p]
                  else
                    params[k] = p
                  end
                end
              when Array
                parameters.each_with_index do |p,i|
                  if p.is_a?(Symbol) && @__weel_data.include?(p)
                    params[p] = @__weel_data[p]
                  else
                    params[i] = p
                  end
                end
              else
                raise("invalid parameters")
            end
            raise Signal::Stop unless handlerwrapper.vote_sync_before(params)
            raise Signal::Skip if self.__weel_state == :stopping || self.__weel_state == :finishing

            if @__weel_search_positions[position]
              passthrough = @__weel_search_positions[position].passthrough
              @__weel_search_positions[position].passthrough = nil
            else
              passthrough = nil
            end

            handlerwrapper.activity_handle passthrough, params
            wp.passthrough = handlerwrapper.activity_passthrough_value
            begin
              # with loop if catching Signal::Again
              # handshake call and wait until it finished
              waitingresult = nil
              waitingresult = Thread.current[:continue].wait unless Thread.current[:nolongernecessary] || self.__weel_state == :stopping || self.__weel_state == :finishing || self.__weel_state == :stopped
              raise waitingresult[1] if !waitingresult.nil? && waitingresult.is_a?(Array) && waitingresult.length == 2 && waitingresult[0] == WEEL::Signal::Error

              if Thread.current[:nolongernecessary]
                handlerwrapper.activity_no_longer_necessary
                raise Signal::NoLongerNecessary
              end
              if self.__weel_state == :stopping || self.__weel_state == :finishing
                handlerwrapper.activity_stop
                wp.passthrough = handlerwrapper.activity_passthrough_value
                raise Signal::Proceed
              end

              code = waitingresult == Signal::Again ? update : finalize
              if code.is_a?(Proc) || code.is_a?(String)
                handlerwrapper.inform_activity_manipulate
                if code.is_a?(Proc)
                  mr = ManipulateStructure.new(@__weel_data,@__weel_endpoints,@__weel_status)
                  case code.arity
                    when 1; mr.instance_exec(handlerwrapper.activity_result_value,&code)
                    when 2; mr.instance_exec(handlerwrapper.activity_result_value,&code)
                    else
                      mr.instance_exec(&code)
                  end
                elsif code.is_a?(String)
                  mr = ManipulateStructure.new(@__weel_data,@__weel_endpoints,@__weel_status)
                  handlerwrapper.manipulate(mr,code,handlerwrapper.activity_result_value)
                end
                handlerwrapper.inform_manipulate_change(
                  (mr.changed_status ? @__weel_status : nil),
                  (mr.changed_data.any? ? mr.changed_data.uniq : nil),
                  (mr.changed_endpoints.any? ? mr.changed_endpoints.uniq : nil),
                  @__weel_data,
                  @__weel_endpoints
                )
              end
            end while waitingresult == Signal::Again
            if handlerwrapper.activity_passthrough_value.nil?
              handlerwrapper.inform_activity_done
              wp.detail = :after
              @__weel_handlerwrapper::inform_position_change @__weel_handlerwrapper_args, :after => [wp.position]
            end
        end
        raise Signal::Proceed
      rescue Signal::SkipManipulate, Signal::Proceed
        if self.__weel_state != :stopping && self.__weel_state != :finishing && !handlerwrapper.vote_sync_after
          self.__weel_state = :stopping
          wp.detail = :unmark
        end
      rescue Signal::NoLongerNecessary
        @__weel_positions.delete wp
        Thread.current[:branch_position] = nil
        wp.detail = :unmark
        @__weel_handlerwrapper::inform_position_change @__weel_handlerwrapper_args, :unmark => [wp.position]
      rescue Signal::StopSkipManipulate, Signal::Stop
        self.__weel_state = :stopping
      rescue Signal::Skip
        nil
      rescue SyntaxError => se
        handlerwrapper.inform_activity_failed se
        self.__weel_state = :stopping
      rescue => err
        handlerwrapper.inform_activity_failed err
        self.__weel_state = :stopping
      ensure
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
        @__weel_handlerwrapper::inform_syntax_error(@__weel_handlerwrapper_args,Exception.new("position (#{position}) not valid"),nil)
      end
    end # }}}

    def __weel_is_in_search_mode(position = nil)# {{{
      branch = Thread.current
      return false if @__weel_search_positions.empty? || branch[:branch_search] == false

      if position && @__weel_search_positions.include?(position) # matching searchpos => start execution from here
        branch[:branch_search] = false # execute all activities in THIS branch (thread) after this point
        while branch.key?(:branch_parent) # also all parent branches should execute activities after this point, additional branches spawned by parent branches should still be in search mode
          branch = branch[:branch_parent]
          branch[:branch_search] = false
        end
        @__weel_search_positions[position].detail == :after ? :after : false
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
      handlerwrapper = @__weel_handlerwrapper.new @__weel_handlerwrapper_args
      handlerwrapper.simulate(what,:start,Thread.current[:branch_sim_pos],current_branch_sim_pos,options)
      [handlerwrapper, current_branch_sim_pos]
    end #}}}

    def __weel_sim_stop(what,handlerwrapper,current_branch_sim_pos,options={}) #{{{
      handlerwrapper.simulate(what,:end,Thread.current[:branch_sim_pos],current_branch_sim_pos,options)
      Thread.current[:branch_sim_pos] = current_branch_sim_pos
    end #}}}

  public
    def __weel_finalize #{{{
      __weel_recursive_join(@__weel_main)
      @__weel_state = :stopped
      @__weel_handlerwrapper::inform_state_change @__weel_handlerwrapper_args, @__weel_state
    end #}}}

    def __weel_state=(newState)# {{{
      return @__weel_state if newState == @__weel_state && @__weel_state != :ready

      @__weel_positions = Array.new if newState == :running
      @__weel_state = newState

      if newState == :stopping || newState == :finishing
        @__weel_status.nudge!
        __weel_recursive_continue(@__weel_main)
      end

      @__weel_handlerwrapper::inform_state_change @__weel_handlerwrapper_args, @__weel_state
    end # }}}

  end # }}}

public
  def positions # {{{
    @dslr.__weel_positions
  end # }}}

  # set the handlerwrapper
  def handlerwrapper # {{{
    @dslr.__weel_handlerwrapper
  end # }}}
  def handlerwrapper=(new_weel_handlerwrapper) # {{{
    superclass = new_weel_handlerwrapper
    while superclass
      check_ok = true if superclass == WEEL::HandlerWrapperBase
      superclass = superclass.superclass
    end
    raise "Handlerwrapper is not inherited from HandlerWrapperBase" unless check_ok
    @dslr.__weel_handlerwrapper = new_weel_handlerwrapper
  end # }}}

  # Get/Set the handlerwrapper arguments
  def handlerwrapper_args # {{{
    @dslr.__weel_handlerwrapper_args
  end # }}}
  def handlerwrapper_args=(args) # {{{
    if args.class == Array
      @dslr.__weel_handlerwrapper_args = args
    end
    nil
  end #  }}}

  # Get the state of execution (ready|running|stopping|stopped|finished|simulating)
  def state # {{{
    @dslr.__weel_state
  end #  }}}
  def state_signal # {{{
    handlerwrapper::inform_state_change handlerwrapper_args, state
    state
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
          @dslr.__weel_handlerwrapper::inform_syntax_error(@dslr.__weel_handlerwrapper_args,Exception.new(se.message),code)
        rescue NameError => err # don't look into it, or it will explode
          @dslr.__weel_state = :stopping
          @dslr.__weel_handlerwrapper::inform_syntax_error(@dslr.__weel_handlerwrapper_args,Exception.new("main: `#{err.name}` is not a thing that can be used. Maybe it is meant to be a string and you forgot quotes?"),code)
        rescue => err
          @dslr.__weel_state = :stopping
          @dslr.__weel_handlerwrapper::inform_syntax_error(@dslr.__weel_handlerwrapper_args,Exception.new(err.message),code)
        end
        if @dslr.__weel_state == :running || @dslr.__weel_state == :finishing
          ipc = { :unmark => [] }
          @dslr.__weel_positions.each{ |wp| ipc[:unmark] << wp.position }
          @dslr.__weel_positions.clear
          @dslr.__weel_handlerwrapper::inform_position_change(@dslr.__weel_handlerwrapper_args,ipc)
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
      @dslr.__weel_state = :stopping
      @dslr.__weel_main.join if @dslr.__weel_main
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
        handlerwrapper::inform_handlerwrapper_error handlerwrapper_args, e
      end
    end
  end # }}}

  def sim # {{{
    stat = @dslr.__weel_state
    return nil unless stat == :ready || stat == :stopped
    @dslr.__weel_main = Thread.new do
      __weel_control_flow :simulating, stat
    end
  end # }}}

end

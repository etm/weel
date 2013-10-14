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

# OMG!111! strings have to be emptied
class String # {{{
  def clear
      self.slice!(0..-1)
  end
end # }}}

# OMG!111! deep cloning for ReadHashes
class Object #{{{
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
      
    ### 1.8
    initialize_search if methods.include?('initialize_search')
    initialize_data if methods.include?('initialize_data')
    initialize_endpoints if methods.include?('initialize_endpoints')
    initialize_handlerwrapper if methods.include?('initialize_handlerwrapper')
    initialize_control if methods.include?('initialize_control')
    ### 1.9
    initialize_search if methods.include?(:initialize_search)
    initialize_data if methods.include?(:initialize_data)
    initialize_endpoints if methods.include?(:initialize_endpoints)
    initialize_handlerwrapper if methods.include?(:initialize_handlerwrapper)
    initialize_control if methods.include?(:initialize_control)
  end # }}}

  module Signal # {{{
    class SkipManipulate < Exception; end
    class StopSkipManipulate < Exception; end
    class Stop < Exception; end
    class Proceed < Exception; end
    class NoLongerNecessary < Exception; end
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
      @__weel_endpoints = endpoints
      @__weel_status = status
      @changed_status = status.id
      @changed_data = []
      @changed_endpoints = []
    end

    attr_reader :changed_data, :changed_endpoints

    def original_data
      @weel_data
    end

    def original_endpoints
      @weel_endpoints
    end

    def changed_status
      @changed_status != status.id
    end

    def data
      ManipulateHash.new(@__weel_data,@changed_data)
    end
    def endpoints
      ManipulateHash.new(@__weel_endpoints,@changed_endpoints)
    end
    def status
      @__weel_status
    end
  end # }}}
  class ManipulateHash # {{{
    def initialize(values,what)
      @__weel_values = values
      @__weel_what = what
    end

    def delete(value)
      if @__weel_values.has_key?(value)
        @__weel_what << value
        @__weel_values.delete(value)
      end  
    end

    def clear
      @__weel_what += @__weel_values.keys
      @__weel_values.clear
    end

    def method_missing(name,*args)
      if args.empty? && @__weel_values.has_key?(name)
        @__weel_values[name] 
      elsif name.to_s[-1..-1] == "=" && args.length == 1
        temp = name.to_s[0..-2]
        @__weel_what << temp.to_sym
        @__weel_values[temp.to_sym] = args[0]
      elsif name.to_s == "[]=" && args.length == 2  
        @__weel_values[args[0]] = args[1] 
      elsif name.to_s == "[]" && args.length == 1
        @__weel_values[args[0]]
      else
        nil
      end
    end
  end # }}}

  class Status #{{{
    def initialize(id,message)
      @id        = id
      @message   = message
    end
    def update(id,message)
      @id        = id
      @message   = message
    end
    attr_reader :id, :message
  end #}}}
  
  class ReadHash # {{{
    def initialize(values)
      @__weel_values = values
    end

    def method_missing(name,*args)
      temp = nil
      if args.empty? && @__weel_values.has_key?(name)
        @__weel_values[name] 
        #TODO dont let user change stuff e.g. if return value is an array (deep clone and/or deep freeze it?)
      else
        nil
      end
    end
  end # }}}

  class HandlerWrapperBase # {{{
    def initialize(arguments,endpoint=nil,position=nil,continue=nil); end

    def activity_handle(passthrough, parameters); end

    def activity_result_value; end
    def activity_result_status; end

    def activity_stop; end
    def activity_passthrough_value; end

    def activity_no_longer_necessary; end

    def inform_activity_done; end
    def inform_activity_manipulate; end
    def inform_activity_failed(err); end

    def inform_syntax_error(err,code); end
    def inform_manipulate_change(status,data,endpoints); end
    def inform_position_change(ipc); end
    def inform_state_change(newstate); end
    
    def vote_sync_before(parameters=nil); true; end
    def vote_sync_after; true; end

    # type       => activity, loop, parallel, choice
    # nesting    => none, start, end
    # eid        => id's also for control structures
    # parameters => stuff given to the control structure
    def simulate(type,nesting,eid,parent,parameters={}); end

    def callback(result); end

    def test_condition(code); eval(code); end
    def manipulate(mr,code,result=nil,status=nil); mr.instance_eval(code); end
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

   class Continue #{{{
     def initialize
       @q = Queue.new
       @m = Mutex.new
     end  
     def waiting?
       @m.synchronize do
         !@q.empty?
       end  
     end  
     def continue
       @q.push nil
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
  def self::flow #{{{
  end #}}}

  class DSLRealization # {{{
    def initialize
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
    end
    attr_accessor :__weel_search_positions, :__weel_positions, :__weel_main, :__weel_data, :__weel_endpoints, :__weel_handlerwrapper, :__weel_handlerwrapper_args
    attr_reader :__weel_state, :__weel_status

    # DSL-Constructs for atomic calls to external services (calls) and pure context manipulations (manipulate).
    # Calls can also manipulate context (after the invoking the external services)
    # position: a unique identifier within the wf-description (may be used by the search to identify a starting point)
    # endpoint: (only with :call) ep of the service
    # parameters: (only with :call) service parameters
    def call(position, endpoint, parameters={}, code=nil, &blk)
      __weel_activity(position,:call,endpoint,parameters,code||blk)
    end  
    def manipulate(position, code=nil, &blk)
      __weel_activity(position,:manipulate,nil,{},code||blk)
    end  
    
    # Parallel DSL-Construct
    # Defines Workflow paths that can be executed parallel.
    # May contain multiple branches (parallel_branch)
    def parallel(type=nil)# {{{
      return if self.__weel_state == :stopping || self.__weel_state == :stopped || Thread.current[:nolongernecessary]

      Thread.current[:branches] = []
      Thread.current[:branch_finished_count] = 0
      Thread.current[:branch_event] = Continue.new
      Thread.current[:mutex] = Mutex.new

      hw, pos = __weel_sim_start(:parallel) if __weel_sim

      yield

      Thread.current[:branch_wait_count] = (type.is_a?(Hash) && type.size == 1 && type[:wait] != nil && (type[:wait].is_a?(Integer)) ? type[:wait] : Thread.current[:branches].size)
      Thread.current[:branches].each do |thread| 
        while thread.status != 'sleep' && thread.alive?
          Thread.pass
        end
        # decide after executing block in parallel cause for coopis
        # it goes out of search mode while dynamically counting branches
        if Thread.current[:branch_search] == false
          thread[:branch_search] = false
        end  
        thread.wakeup if thread.alive?
      end

      Thread.current[:branch_event].wait

      __weel_sim_stop(:parallel,hw,pos) if __weel_sim

      unless self.__weel_state == :stopping || self.__weel_state == :stopped
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
      return if self.__weel_state == :stopping || self.__weel_state == :stopped || Thread.current[:nolongernecessary]
      branch_parent = Thread.current

      if __weel_sim
        # catch the potential execution in loops inside a parallel
        current_branch_sim_pos = branch_parent[:branch_sim_pos]
      end  

      Thread.current[:branches] << Thread.new(*vars) do |*local|
        branch_parent[:mutex].synchronize do
          Thread.current.abort_on_exception = true
          Thread.current[:branch_status] = false
          Thread.current[:branch_parent] = branch_parent

          if __weel_sim
            Thread.current[:branch_sim_pos] = @__weel_sim += 1
          end  

          # parallel_branch could be possibly around an alternative. Thus thread has to inherit the alternative_executed
          # after branching, update it in the parent (TODO)
          if branch_parent[:alternative_executed] && branch_parent[:alternative_executed].length > 0
            Thread.current[:alternative_executed] = [branch_parent[:alternative_executed].last]
            Thread.current[:alternative_mode] = [branch_parent[:alternative_mode].last]
          end
        end  

        Thread.stop

        if __weel_sim
          handlerwrapper = @__weel_handlerwrapper.new @__weel_handlerwrapper_args
          handlerwrapper.simulate(:parallel_branch,:start,Thread.current[:branch_sim_pos],current_branch_sim_pos)
        end

        yield(*local)

        __weel_sim_stop(:parallel_branch,handlerwrapper,current_branch_sim_pos) if __weel_sim

        branch_parent[:mutex].synchronize do
          Thread.current[:branch_status] = true
          branch_parent[:branch_finished_count] += 1
          if branch_parent[:branch_finished_count] == branch_parent[:branch_wait_count] && self.__weel_state != :stopping
            branch_parent[:branch_event].continue
          end  
        end  
        if self.__weel_state != :stopping && self.__weel_state != :stopped
          if Thread.current[:branch_position]
            @__weel_positions.delete Thread.current[:branch_position]
            begin
              ipc = {}
              ipc[:unmark] = [Thread.current[:branch_position].position]
              handlerwrapper = @__weel_handlerwrapper.new @__weel_handlerwrapper_args
              handlerwrapper.inform_position_change(ipc)
            end rescue nil
            Thread.current[:branch_position] = nil
          end  
        end  
      end
      Thread.pass
    end # }}}

    # Choose DSL-Construct
    # Defines a choice in the Workflow path.
    # May contain multiple execution alternatives
    def choose(mode=:inclusive) # {{{
      return if self.__weel_state == :stopping || self.__weel_state == :stopped || Thread.current[:nolongernecessary]
      Thread.current[:alternative_executed] ||= []
      Thread.current[:alternative_mode] ||= []
      Thread.current[:alternative_executed] << false
      Thread.current[:alternative_mode] << mode
      hw, pos = __weel_sim_start(:choose,:mode => Thread.current[:alternative_mode].last) if __weel_sim
      yield
      __weel_sim_stop(:choose,hw,pos,:mode => Thread.current[:alternative_mode].last) if __weel_sim
      Thread.current[:alternative_executed].pop
      Thread.current[:alternative_mode].pop
      nil
    end # }}}

    # Defines a possible choice of a choose-Construct
    # Block is executed if condition == true or
    # searchmode is active (to find the starting position)
    def alternative(condition)# {{{
      return if self.__weel_state == :stopping || self.__weel_state == :stopped || Thread.current[:nolongernecessary]
      hw, pos = __weel_sim_start(:alternative,:mode => Thread.current[:alternative_mode]) if __weel_sim
      Thread.current[:mutex] ||= Mutex.new
      Thread.current[:mutex].synchronize do
        return if Thread.current[:alternative_mode] == :exclusive && Thread.current[:alternative_executed][-1] = true
        if condition.is_a?(String) && !__weel_sim
          handlerwrapper = @__weel_handlerwrapper.new @__weel_handlerwrapper_args
          condition = handlerwrapper.test_condition(ReadStructure.new(@__weel_data,@__weel_endpoints),__condition)
        end
        Thread.current[:alternative_executed][-1] = true if condition
      end  
      yield if __weel_is_in_search_mode || __weel_sim || condition
      __weel_sim_stop(:alternative,hw,pos,:mode => Thread.current[:alternative_mode]) if __weel_sim
    end # }}}
    def otherwise # {{{
      return if self.__weel_state == :stopping || self.__weel_state == :stopped || Thread.current[:nolongernecessary]
      hw, pos = __weel_sim_start(:otherwise,:mode => Thread.current[:alternative_mode]) if __weel_sim
      yield if __weel_is_in_search_mode || __weel_sim || !Thread.current[:alternative_executed].last
      __weel_sim_stop(:otherwise,hw,pos,:mode => Thread.current[:alternative_mode]) if __weel_sim
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
        yield
      end
    end # }}}

    # Defines a Cycle (loop/iteration)
    def loop(condition)# {{{ 
      unless condition.is_a?(Array) && (condition[0].is_a?(Proc) || condition[0].is_a?(String)) && [:pre_test,:post_test].include?(condition[1])
        raise "condition must be called pre_test{} or post_test{}"
      end
      return if self.__weel_state == :stopping || self.__weel_state == :stopped || Thread.current[:nolongernecessary]
      if __weel_is_in_search_mode
        yield
        return if __weel_is_in_search_mode
      end  
      if __weel_sim
        hw, pos = __weel_sim_start(:loop,:testing=>condition[1])
        yield
        __weel_sim_stop(:loop,hw,pos,:testing=>condition[1])
        return
      end
      handlerwrapper = @__weel_handlerwrapper.new @__weel_handlerwrapper_args unless condition[0].is_a?(Proc)
      case condition[1]
        when :pre_test
          yield while (condition[0].is_a?(Proc) ? condition[0].call : handlerwrapper.test_condition(ReadStructure.new(@__weel_data,@__weel_endpoints),condition[0])) && self.__weel_state != :stopping && self.__weel_state != :stopped
        when :post_test
          begin; yield; end while (condition[0].is_a?(Proc) ? condition[0].call : handlerwrapper.test_condition(ReadStructure.new(@__weel_data,@__weel_endpoints),condition[0])) && self.__weel_state != :stopping && self.__weel_state != :stopped
      end
    end # }}}

    def pre_test(code=nil,&blk)# {{{
      [code || blk, :pre_test]
    end # }}}
    def post_test(code=nil,&blk)# {{{
      [code || blk, :post_test]
    end # }}}

    def status # {{{
      @__weel_status
    end # }}}
    def data # {{{
      ReadHash.new(@__weel_data)
    end # }}}
    def endpoints # {{{
      ReadHash.new(@__weel_endpoints)
    end # }}}

  private
    def __weel_activity(position, type, endpoint, parameters, code)# {{{
      position = __weel_position_test position
      begin
        searchmode = __weel_is_in_search_mode(position)
        return if searchmode == true
        return if self.__weel_state == :stopping || self.__weel_state == :stopped || Thread.current[:nolongernecessary]

        Thread.current[:continue] = Continue.new
        handlerwrapper = @__weel_handlerwrapper.new @__weel_handlerwrapper_args, @__weel_endpoints[endpoint], position, Thread.current[:continue]

        if __weel_sim
          handlerwrapper.simulate(:activity,:none,position,Thread.current[:branch_sim_pos],:parameters=>parameters, :endpoint => endpoint, :type => type)
          return
        end

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
          wp = WEEL::Position.new(position, :at, nil)
          ipc[:at] = [wp.position]
        end
        @__weel_positions << wp
        Thread.current[:branch_position] = wp

        handlerwrapper.inform_position_change(ipc)

        # searchmode position is after, jump directly to vote_sync_after
        raise Signal::Proceed if searchmode == :after

        case type
          when :manipulate
            raise Signal::Stop unless handlerwrapper.vote_sync_before

            if code.is_a?(Proc) || code.is_a?(String)
              handlerwrapper.inform_activity_manipulate
              if code.is_a?(Proc)
                mr = ManipulateStructure.new(@__weel_data,@__weel_endpoints,@__weel_status)
                mr.instance_eval(&code)
              elsif code.is_a?(String)  
                mr = ManipulateStructure.new(@__weel_data,@__weel_endpoints,@__weel_status)
                handlerwrapper.manipulate(mr,code)
              end  
              handlerwrapper.inform_manipulate_change(
                ((mr && mr.changed_status) ? @__weel_status : nil), 
                ((mr && mr.changed_data.any?) ? mr.changed_data.uniq : nil),
                ((mr && mr.changed_endpoints.any?) ? mr.changed_endpoints.uniq : nil)
              )
              handlerwrapper.inform_activity_done
              wp.detail = :after
              handlerwrapper.inform_position_change :after => [wp.position]
            end  
          when :call
            params = { }
            case parameters 
              when String
                code = parameters
                parameters = nil
              when Hash
                parameters.each do |k,p|
                  if p.is_a?(Symbol) && @__weel_data.include?(p)
                    params[k] = @__weel_data[p]
                  elsif k == :code && p.is_a?(String)
                    code = p
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

            passthrough = @__weel_search_positions[position] ? @__weel_search_positions[position].passthrough : nil
            # handshake call and wait until it finished
            handlerwrapper.activity_handle passthrough, params
            Thread.current[:continue].wait unless Thread.current[:nolongernecessary] || self.__weel_state == :stopping || self.__weel_state == :stopped

            if Thread.current[:nolongernecessary]
              handlerwrapper.activity_no_longer_necessary 
              raise Signal::NoLongerNecessary
            end  
            if self.__weel_state == :stopping
              handlerwrapper.activity_stop
              wp.passthrough = handlerwrapper.activity_passthrough_value
            end  

            if wp.passthrough.nil? && (code.is_a?(Proc) || code.is_a?(String))
              handlerwrapper.inform_activity_manipulate
              status = handlerwrapper.activity_result_status
              if code.is_a?(Proc)
                mr = ManipulateStructure.new(@__weel_data,@__weel_endpoints,@__weel_status)
                case code.arity
                  when 1; mr.instance_exec(handlerwrapper.activity_result_value,&code)
                  when 2; mr.instance_exec(handlerwrapper.activity_result_value,(status.is_a?(Status)?status:nil),&code)
                  else
                    mr.instance_eval(&code)
                end  
              elsif code.is_a?(String)  
                mr = ManipulateStructure.new(@__weel_data,@__weel_endpoints,@__weel_status)
                handlerwrapper.manipulate(mr,code,handlerwrapper.activity_result_value,(status.is_a?(Status)?status:nil))
              end
              handlerwrapper.inform_manipulate_change(
                (mr.changed_status ? @__weel_status : nil), 
                (mr.changed_data.any? ? mr.changed_data.uniq : nil),
                (mr.changed_endpoints.any? ? mr.changed_endpoints.uniq : nil)
              )
            end
            if wp.passthrough.nil?
              handlerwrapper.inform_activity_done
              wp.detail = :after
              handlerwrapper.inform_position_change :after => [wp.position]
            end  
        end
        raise Signal::Proceed
      rescue Signal::SkipManipulate, Signal::Proceed
        if self.__weel_state != :stopping && !handlerwrapper.vote_sync_after
          self.__weel_state = :stopping
          wp.detail = :unmark
        end
      rescue Signal::NoLongerNecessary
        @__weel_positions.delete wp
        Thread.current[:branch_position] = nil
        wp.detail = :unmark
        handlerwrapper.inform_position_change :unmark => [wp.position]
      rescue Signal::StopSkipManipulate, Signal::Stop
        self.__weel_state = :stopping
      rescue => err
        handlerwrapper.inform_activity_failed err
        self.__weel_state = :stopping
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
        handlerwrapper = @__weel_handlerwrapper.new @__weel_handlerwrapper_args
        handlerwrapper.inform_syntax_error(Exception.new("position (#{position}) not valid"),nil)
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

    def __weel_sim
      @__weel_state == :simulating
    end

    def __weel_sim_start(what,options={})
      current_branch_sim_pos = Thread.current[:branch_sim_pos]
      Thread.current[:branch_sim_pos] = @__weel_sim += 1
      handlerwrapper = @__weel_handlerwrapper.new @__weel_handlerwrapper_args
      handlerwrapper.simulate(what,:start,Thread.current[:branch_sim_pos],current_branch_sim_pos,options)
      [handlerwrapper, current_branch_sim_pos]
    end  

    def __weel_sim_stop(what,handlerwrapper,current_branch_sim_pos,options={})
      handlerwrapper.simulate(what,:end,Thread.current[:branch_sim_pos],current_branch_sim_pos,options)
      Thread.current[:branch_sim_pos] = current_branch_sim_pos
    end
  
  public
    def __weel_finalize
      __weel_recursive_join(@__weel_main)
      @__weel_state = :stopped
      handlerwrapper = @__weel_handlerwrapper.new @__weel_handlerwrapper_args
      handlerwrapper.inform_state_change @__weel_state
    end

    def __weel_state=(newState)# {{{
      return @__weel_state if newState == @__weel_state
      @__weel_positions = Array.new if @__weel_state != newState && newState == :running
      handlerwrapper = @__weel_handlerwrapper.new @__weel_handlerwrapper_args
      @__weel_state = newState

      if newState == :stopping
        __weel_recursive_continue(@__weel_main)
      end
  
      handlerwrapper.inform_state_change @__weel_state
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
      new_data.each{|k,v|@dslr.__weel_data[k] = v}
    end
    @dslr.__weel_data
  end # }}}
  def endpoints(new_endpoints=nil) # {{{
    unless new_endpoints.nil? || !new_endpoints.is_a?(Hash)
      new_endpoints.each{|k,v|@dslr.__weel_endpoints[k] = v}
    end
    @dslr.__weel_endpoints
  end # }}}
  def endpoint(new_endpoints) # {{{
    unless new_endpoints.nil? || !new_endpoints.is_a?(Hash) || !new_endpoints.length == 1
      new_endpoints.each{|k,v|@dslr.__weel_endpoints[k] = v}
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
  def description=(code)  # {{{
    (class << self; self; end).class_eval do
      define_method :__weel_control_flow do |state,final_state=:finished|
        @dslr.__weel_positions.clear
        @dslr.__weel_state = state
        begin
          if code.is_a? Proc
            @dslr.instance_eval(&code)
          else  
            @dslr.instance_eval(code)
          end  
        rescue Exception => err
          @dslr.__weel_state = :stopping
          handlerwrapper = @dslr.__weel_handlerwrapper.new @dslr.__weel_handlerwrapper_args
          handlerwrapper.inform_syntax_error(err,code)
        end
        if @dslr.__weel_state == :running
          @dslr.__weel_state = :finished 
          ipc = { :unmark => [] }
          @dslr.__weel_positions.each{|wp| ipc[:unmark] << wp.position}
          @dslr.__weel_positions.clear
          handlerwrapper = @dslr.__weel_handlerwrapper.new @dslr.__weel_handlerwrapper_args
          handlerwrapper.inform_position_change(ipc)
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
      __weel_control_flow(:running)
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

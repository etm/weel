require 'test/unit'
require 'timeout'
require File.expand_path(::File.dirname(__FILE__) + '/../../lib/weel')

# Two sibling parallel branches share their parent thread. When both make
# progress at the same time, __weel_progress in each of them looks at the
# parent's :branch_position to unmark it. Without the take-and-clear under the
# parent's mutex, both can see it set, one clears it, and the other then
# reports nil in ipc[:unmark].
#
# The race is forced deterministically: positions is replaced by an array whose
# delete blocks the first branch that deletes the parent's position, until the
# second branch has completely finished its progress.
class TestProgressRace < Test::Unit::TestCase
  class RecordingWrapper < WEEL::ConnectionWrapperBase
    @@ipcs = Queue.new
    def self::ipcs; @@ipcs; end
    def self::inform_position_change(arguments,ipc={})
      @@ipcs << ipc
    end
  end

  class GatedPositions < Array
    attr_reader :blocked
    def initialize(gated)
      super()
      @gated   = gated
      @first   = true
      @lock    = Mutex.new
      @blocked = Queue.new # signalled when the first branch waits
      @release = Queue.new # opened by the test
    end
    def open; @release << true; end
    def delete(obj)
      wait = @lock.synchronize { (obj.equal?(@gated) && @first).tap { @first = false } }
      if wait
        @blocked << true
        @release.pop
      end
      super
    end
  end

  def test_sibling_progress_never_unmarks_nil
    wf = WEEL.new
    wf.connectionwrapper = RecordingWrapper
    dslr = wf.instance_variable_get(:@dslr)

    parent_pos = WEEL::Position.new(:parent_activity, 'parent-uuid')
    positions = GatedPositions.new(parent_pos)
    positions << parent_pos
    dslr.__weel_positions = positions

    parent = Thread.new { sleep } # stands in for the thread that runs parallel
    parent[:mutex] = Mutex.new
    parent[:branch_position] = parent_pos

    branch = lambda do |name|
      Thread.new do
        Thread.current[:branch_parent] = parent
        dslr.send(:__weel_progress, name, "#{name}-uuid")
      end
    end

    a = branch.call(:a1)
    Timeout.timeout(5) { positions.blocked.pop } # a1 sits inside the unmark of the parent position
    b = branch.call(:a2)
    assert_not_nil b.join(5), 'second branch did not finish'
    positions.open
    assert_not_nil a.join(5), 'first branch did not finish'

    unmarked = []
    unmarked.concat(RecordingWrapper.ipcs.pop[:unmark] || []) until RecordingWrapper.ipcs.empty?

    assert_not_include unmarked, nil, 'a branch reported nil as an unmarked position'
    assert_equal [parent_pos], unmarked, 'the parent position must be unmarked exactly once'
  ensure
    parent&.kill
  end
end

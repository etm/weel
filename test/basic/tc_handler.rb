require 'test/unit'
require File.expand_path(::File.dirname(__FILE__) + '/../TestWorkflow')

class TestCaseHandler < Test::Unit::TestCase
  include TestMixin

  def test_handler
    assert_raise RuntimeError do
      @wf.connectionwrapper = String
    end
    assert_nothing_raised do
      @wf.connectionwrapper = TestConnectionWrapper
    end
  end
  def test_handlerargs
    @wf.connectionwrapper_args =  ["1", "2"]
    assert(@wf.connectionwrapper_args.is_a?(Array), "Handler arguments is not an array, it is a #{@wf.connectionwrapper_args.inspect}")
  end
end

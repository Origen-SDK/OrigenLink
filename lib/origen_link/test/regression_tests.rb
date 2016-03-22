require_relative '..\vector_based'
require_relative 'vector_based_redefs'
require 'test/unit'

class DummyTset
  attr_accessor :name

  def initialize
    @name = 'default'
  end
end

class TestVectorBased < Test::Unit::TestCase
  def test_stuff
    timeset_sim_obj = DummyTset.new

    test_obj = OrigenLink::VectorBased.new('localhost', 12_777)
    # setup pinmap
    test_obj.pinmap = 'tck, 5, tdo, 8, tms, 10, tdi, 15'
    assert_equal('pin_assign:tck,5,tdo,8,tms,10,tdi,15', test_obj.message)

    # setup pin order  ---- notice there's currently no error checking to see if pinmap and pinorder have the same pins !!!
    test_obj.pinorder = 'tck,tdo, tdi, extal'
    assert_equal('pin_patternorder:tck,tdo,tdi,extal', test_obj.message)

    assert_equal(true, test_obj.link?)
    assert_equal('OrigenLink::VectorBased', test_obj.to_s)

    test_obj.message = ''
    test_obj.push_vector(timeset: timeset_sim_obj, pin_vals: '1100')
    # check that pin values are being accumulated and not sent
    assert_equal('', test_obj.message)
    assert_equal(1, test_obj.vector_repeatcount)

    # check that different vector data causes previous to be sent
    test_obj.microcodestr = ''
    test_obj.test_response = 'P:1100'
    test_obj.push_vector(timeset: timeset_sim_obj, pin_vals: '1000')
    assert_equal('pin_cycle:1100', test_obj.message)
    assert_equal('P:1100', test_obj.microcodestr)

    # check that repeat count accumulates
    test_obj.microcodestr = ''
    test_obj.push_vector(timeset: timeset_sim_obj, pin_vals: '1000')
    assert_equal(2, test_obj.vector_repeatcount)

    # check that repeat count is correctly sent
    test_obj.test_response = 'P:repeat2,1000'
    test_obj.flush_vector
    assert_equal('pin_cycle:repeat2,1000', test_obj.message)

    # check pin format setup
    test_obj.test_response = 'P:'
    test_obj.pinformat = 'func_25mhz, tck, rl'
    assert_equal('pin_format:1,tck,rl', test_obj.message)

    # check timing setup
    test_obj.pintiming = 'func_25mhz, tdi, 0, tdo, 1, tms, 0'
    assert_equal('pin_timing:1,tdi,0,tdo,1,tms,0', test_obj.message)

    # check pin_cycle works correctly with tsets programmed
    test_obj.test_response = 'P:tset0,1000'
    timeset_sim_obj.name = 'func_25mhz'
    test_obj.push_vector(timeset: timeset_sim_obj, pin_vals: '1000')
    test_obj.flush_vector
    assert_equal('pin_cycle:tset1,1000', test_obj.message)
  end
end

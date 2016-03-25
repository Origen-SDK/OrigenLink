require_relative "../config/boot"
require 'origen_link/server/sequencer'
require 'test/unit'
require 'byebug'

class TestLinkSequencer < Test::Unit::TestCase
  def test_pinmap
    test_obj = OrigenLink::Server::Sequencer.new
    byebug
    assert_equal('P:', test_obj.processmessage('pin_assign:tck,23'))
    assert_equal('OrigenLinkPin23', test_obj.pinmap['tck'].to_s)
    assert_equal('F:pin tdo gpio1900 is invalid', test_obj.processmessage('pin_assign:tdo,1900'))
    assert_equal('P:', test_obj.processmessage('pin_assign:tck,23'))
    assert_equal('OrigenLinkPin23', test_obj.pinmap['tck'].to_s)
    assert_equal(-1, test_obj.pinmap['tdo'])
  end

  def test_pinorder
    test_obj2 = OrigenLink::Server::Sequencer.new
    assert_equal('P:', test_obj2.processmessage('pin_patternorder:tdi,tdo,tms'))
    assert_equal(%w(tdi tdo tms), test_obj2.patternorder)
    assert_equal({ 'tdi' => 0, 'tdo' => 1, 'tms' => 2 }, test_obj2.patternpinindex)
    assert_equal([%w(tdi tdo tms), [], []], test_obj2.cycletiming[0]['timing'])
  end

  def test_clear
  end

  def test_pinformat_timing
    test_obj3 = OrigenLink::Server::Sequencer.new
    assert_equal('P:', test_obj3.processmessage('pin_format:1,tck,rl'))
    assert_equal(['tck'], test_obj3.cycletiming[1]['rl'])
    assert_equal(nil, test_obj3.cycletiming[1]['rh'])

    assert_equal('P:', test_obj3.processmessage('pin_format:1,xtal,rh'))
    assert_equal(nil, test_obj3.cycletiming[1]['rl'])
    assert_equal(['xtal'], test_obj3.cycletiming[1]['rh'])

    assert_equal('P:', test_obj3.processmessage('pin_format:2,tck,rl'))
    assert_equal(['tck'], test_obj3.cycletiming[2]['rl'])
    assert_equal(nil, test_obj3.cycletiming[2]['rh'])
    assert_equal(nil, test_obj3.cycletiming[1]['rl'])
    assert_equal(['xtal'], test_obj3.cycletiming[1]['rh'])

    assert_equal('P:', test_obj3.processmessage('pin_timing:1,tdi,0,tms,1,tdo,2'))
    assert_equal(['tck'], test_obj3.cycletiming[2]['rl'])
    assert_equal(nil, test_obj3.cycletiming[2]['rh'])
    assert_equal(nil, test_obj3.cycletiming[1]['rl'])
    assert_equal(['xtal'], test_obj3.cycletiming[1]['rh'])
    assert_equal([['tdi'], ['tms'], ['tdo']], test_obj3.cycletiming[1]['timing'])
    assert_equal([[], [], []], test_obj3.cycletiming[2]['timing'])
  end
end

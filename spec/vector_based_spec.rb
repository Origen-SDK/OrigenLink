require 'spec_helper'

describe OrigenLink::VectorBased do

  class DummyTset
    attr_accessor :name

    def initialize
      @name = 'default'
    end
  end

  def timeset_sim_obj
    @timeset_sim_obj
  end

  def test_obj
    @test_obj
  end

  before :all do
    @test_obj = OrigenLink::Test::VectorBased.new('localhost', 12_777)
    @timeset_sim_obj = DummyTset.new
  end

  specify "setup pinmap" do
    test_obj.pinmap = 'tck, 5, tdo, 8, tms, 10, tdi, 15'
    test_obj.message.should == 'pin_assign:tck,5,tdo,8,tms,10,tdi,15'
  end

  specify "setup pin order" do
    # notice there's currently no error checking to see if pinmap and pinorder have the same pins !!!
    test_obj.pinorder = 'tck,tdo, tdi, extal'
    test_obj.message.should == 'pin_patternorder:tck,tdo,tdi,extal'
    test_obj.link?.should == true
    test_obj.to_s.should == 'OrigenLink::VectorBased'
  end


  specify "pin values are being accumulated and not sent" do
    test_obj.message = ''
    test_obj.push_vector(timeset: timeset_sim_obj, pin_vals: '1100')
    test_obj.message.should == ''
    test_obj.vector_repeatcount.should == 1
  end

  specify "that different vector data causes previous to be sent" do
    test_obj.microcodestr = ''
    test_obj.test_response = 'P:1100'
    test_obj.push_vector(timeset: timeset_sim_obj, pin_vals: '1000')
    test_obj.message.should == 'pin_cycle:1100'
    test_obj.microcodestr.should == 'P:1100'
  end

  specify "that repeat count accumulates" do
    test_obj.microcodestr = ''
    test_obj.push_vector(timeset: timeset_sim_obj, pin_vals: '1000')
    test_obj.vector_repeatcount.should == 2
  end

  specify "check that repeat count is correctly sent" do
    test_obj.test_response = 'P:repeat2,1000'
    test_obj.flush_vector
    test_obj.message.should == 'pin_cycle:repeat2,1000'
  end

  specify "pin format setup" do
    test_obj.test_response = 'P:'
    test_obj.pinformat = 'func_25mhz, tck, rl'
    test_obj.message.should == 'pin_format:1,tck,rl'
  end

  specify "timing setup" do
    test_obj.pintiming = 'func_25mhz, tdi, 0, tdo, 1, tms, 0'
    test_obj.message.should == 'pin_timing:1,tdi,0,tdo,1,tms,0'
  end

  specify "pin_cycle works correctly with tsets programmed" do
    test_obj.test_response = 'P:tset0,1000'
    timeset_sim_obj.name = 'func_25mhz'
    test_obj.push_vector(timeset: timeset_sim_obj, pin_vals: '1000')
    test_obj.flush_vector
    test_obj.message.should == 'pin_cycle:tset1,1000'
  end
end

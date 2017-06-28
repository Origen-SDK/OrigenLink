require 'spec_helper'

describe OrigenLink::VectorBased do

  class VecTestDUT
    include Origen::TopLevel

    def initialize
      add_pin :tck
      add_pin :tdo
      add_pin :tms
      add_pin :tdi
    end

  end

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
    Origen.target.temporary = -> { VecTestDUT.new; OrigenLink::Test::VectorBased.new('localhost', 12_777) }
    Origen.target.load!
    tester.message = ''
    tester.set_timeset('tp0', 40)
    tester.pinmap = 'tck, 5, tdo, 8, tms, 10, tdi, 15'
    tester.message = ''
    dut.pins(:tck).drive(1)
    dut.pins(:tdo).drive(1)
    dut.pins(:tms).drive(0)
    dut.pins(:tdi).drive!(0)
    tester.message.should_not =~ /pin_cycle/
    tester.vector_repeatcount.should == 1
  end

  specify "that different vector data causes previous to be sent" do
    Origen.target.temporary = -> { VecTestDUT.new; OrigenLink::Test::VectorBased.new('localhost', 12_777) }
    Origen.target.load!
    tester.message = ''
    tester.set_timeset('tp0', 40)
    tester.pinmap = 'tck, 5, tdo, 8, tms, 10, tdi, 15'
    tester.message = ''
    dut.pins(:tck).drive(1)
    dut.pins(:tdo).drive(1)
    dut.pins(:tms).drive(0)
    dut.pins(:tdi).drive!(0)
    tester.microcodestr = ''
    tester.test_response = 'P:1100'
    dut.pins(:tdo).drive!(0)
    tester.vector_batch.should == ['pin_cycle:1100']
  end

  specify "that repeat count accumulates" do
    Origen.target.temporary = -> { VecTestDUT.new; OrigenLink::Test::VectorBased.new('localhost', 12_777) }
    Origen.target.load!
    tester.message = ''
    tester.set_timeset('tp0', 40)
    tester.pinmap = 'tck, 5, tdo, 8, tms, 10, tdi, 15'
    tester.message = ''
    dut.pins(:tck).drive(1)
    dut.pins(:tdo).drive(1)
    dut.pins(:tms).drive(0)
    dut.pins(:tdi).drive!(0)
    tester.microcodestr = ''
    tester.vector_repeatcount.should == 1
    tester.cycle
    tester.vector_repeatcount.should == 2
    tester.cycle repeat: 20
    tester.vector_repeatcount.should == 22
  end

  specify "check that repeat count is correctly sent" do
    Origen.target.temporary = -> { VecTestDUT.new; OrigenLink::Test::VectorBased.new('localhost', 12_777) }
    Origen.target.load!
    tester.message = ''
    tester.set_timeset('tp0', 40)
    tester.pinmap = 'tck, 5, tdo, 8, tms, 10, tdi, 15'
    tester.message = ''
    dut.pins(:tck).drive(1)
    dut.pins(:tdo).drive(1)
    dut.pins(:tms).drive(0)
    dut.pins(:tdi).drive!(0)
    tester.microcodestr = ''
    tester.cycle
    tester.test_response = 'P:repeat2,1100'
    tester.flush_vector
    tester.vector_batch.should == ['pin_cycle:repeat2,1100']
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
    Origen.target.temporary = -> { VecTestDUT.new; OrigenLink::Test::VectorBased.new('localhost', 12_777) }
    Origen.target.load!
    tester.message = ''
    tester.set_timeset('func_25mhz', 40)
    tester.pinmap = 'tck, 5, tdo, 8, tms, 10, tdi, 15'
    tester.pintiming = 'func_25mhz, tdi, 0, tdo, 1, tms, 0'
    tester.message = ''
    dut.pins(:tck).drive(1)
    dut.pins(:tdo).drive(1)
    dut.pins(:tms).drive(0)
    dut.pins(:tdi).drive!(0)
    tester.microcodestr = ''
    tester.cycle
    tester.test_response = 'P:repeat2,1100'
    tester.flush_vector
    tester.vector_batch.should == ['pin_cycle:tset1,repeat2,1100']
  end
  
  # TODO: Add tests to check capture and comment batching alignment with batched vectors
end

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

  specify "vectors for capture aren't compressed" do
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
    tester.store_next_cycle(:tdo)
    tester.cycle
    tester.cycle
    tester.cycle
    tester.flush_vector
    tester.vector_batch.should == ["pin_cycle:1100", "pin_cycle:1100", "pin_cycle:repeat2,1100"]
    tester.store_pins_batch.should == {1=>[:tdo]}
    Origen.target.unload!
  end

end

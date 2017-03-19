require 'spec_helper'

describe OrigenLink::VectorBased do

  class PinOrderTestDUT
    include Origen::TopLevel

    def initialize
      add_pin :tclk
      add_pin :tdo
      add_pin :tms
      add_pin :port_a, size: 8
      
      pin_pattern_order :tms, :port_a, :tdo, :tclk
    end
  end

  before :all do
    Origen.target.temporary = -> { PinOrderTestDUT.new ;OrigenLink::Test::VectorBased.new('localhost', 12_777) }
    Origen.target.load!
  end

  specify "auto setup pin order" do
    tester.pinmap = 'tck, 5, tdo, 8, tms, 10, tdi, 15'
    tester.message.should == 'pin_assign:tck,5,tdo,8,tms,10,tdi,15'
    tester.set_timeset("nvmbist", 40)
    tester.cycle
    tester.message.should == 'pin_patternorder:tms,port_a,tdo,tclk'
  end
end
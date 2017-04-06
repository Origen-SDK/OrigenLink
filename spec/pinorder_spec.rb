require 'spec_helper'

describe OrigenLink::VectorBased do

  class PinOrderTestDUT
    include Origen::TopLevel

    def initialize
      add_pin :tclk
      add_pin :tdo
      add_pin :tms
      add_pin :port_a, size: 8
      add_pin :pb0
      add_pin :pb1
      add_pin :pb2
      add_pin :pb3
      add_pin_group :pb, :pb3, :pb2, :pb1, :pb0
      
      pin_pattern_order :tms, :port_a, :tdo, :tclk, :pb
    end
  end

  class PinOrderTestDUT_only
    include Origen::TopLevel

    def initialize
      add_pin :tclk
      add_pin :tdo
      add_pin :tms
      add_pin :port_a, size: 8
      
      pin_pattern_order :tms, :tdo, :tclk, only: true
    end
  end

  specify "auto setup pin order" do
    Origen.target.temporary = -> { PinOrderTestDUT.new ;OrigenLink::Test::VectorBased.new('localhost', 12_777) }
    Origen.target.load!
    tester.pinmap = 'tclk, 5, tdo, 8, tms, 10, tdi, 15, port_a7, 2, port_a6, 2,port_a5, 2,port_a4, 2,port_a3, 2,port_a2, 2,port_a1, 2,port_a0, 2,pb1, 3'
    tester.set_timeset("nvmbist", 40)
    tester.cycle
    tester.message.should == 'pin_patternorder:tms,port_a7,port_a6,port_a5,port_a4,port_a3,port_a2,port_a1,port_a0,tdo,tclk,pb1'
  end

  specify "auto setup pin order with only true" do
    Origen.target.temporary = -> { PinOrderTestDUT_only.new ;OrigenLink::Test::VectorBased.new('localhost', 12_777) }
    Origen.target.load!
    tester.pinmap = 'tclk, 5, tdo, 8, tms, 10, tdi, 15'
    tester.set_timeset("nvmbist", 40)
    tester.cycle
    tester.message.should == 'pin_patternorder:tms,tdo,tclk'
  end
end
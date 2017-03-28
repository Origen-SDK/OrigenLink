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
    tester.pinmap = 'tclk, 5, tdo, 8, tms, 10, tdi, 15'
    tester.set_timeset("nvmbist", 40)
    tester.cycle
    tester.message.should == 'pin_patternorder:tms,tdo,tclk'
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
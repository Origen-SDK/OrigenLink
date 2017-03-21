require 'spec_helper'

describe 'Timing API interpreter' do

  class TimingAPITestDUT
    include Origen::TopLevel

    def initialize
      add_pin :tck
      add_pin :tdo
      add_pin :tms
      add_pin :tdi
    end

  end

  specify 'interprets nr timing format' do
    Origen.target.temporary = -> { TimingAPITestDUT.new; OrigenLink::Test::VectorBased.new('localhost', 12_777) }
    Origen.target.load!
    tester.pinmap = 'tck, 5, tdo, 8, tms, 10, tdi, 15'
    tester.pinorder = 'tck, tdo, tms, tdi'
    tester.set_timeset("nvmbist", 40)
    tester.message = ''
debugger
    tester.cycle
    tester.message.should == ''
  end
  
end

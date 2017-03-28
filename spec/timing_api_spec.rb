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
    tester.message = ''
    tester.set_timeset('tp0', 40)
    dut.timeset :tp0 do |t|
      t.wave :tck do |w|
        w.drive :data, at: 20
      end
      t.wave :tdi, :tdo, :tms do |w|
        w.drive :data, at: 5
      end
      t.wave do |w|
        w.compare :data, at: 35
      end
    end
    # temporarily force
    dut.current_timeset_period = 40

    dut.pin(:tdi).drive!(0)
    dut.pin(:tdi).drive!(1)
    tester.message.should == 'pin_timingv2:1,drive,5.0,data,tdo,tms,tdi;20.0,data,tck|compare,35.0,data,tck,tdo,tms,tdi'
  end
  
  specify 'interprets rl timing format' do
    Origen.target.temporary = -> { TimingAPITestDUT.new; OrigenLink::Test::VectorBased.new('localhost', 12_777) }
    Origen.target.load!
    tester.pinmap = 'tck, 5, tdo, 8, tms, 10, tdi, 15'
    tester.pinorder = 'tck, tdo, tms, tdi'
    tester.message = ''
    tester.set_timeset('tp0', 40)
    dut.timeset :tp0 do |t|
      t.wave :tck do |w|
        w.drive :data, at: 10
        w.drive 0, at: 30
      end
      t.wave :tdi, :tdo, :tms do |w|
        w.drive :data, at: 0
      end
      t.wave do |w|
        w.compare :data, at: 40
      end
    end
    # temporarily force
    dut.current_timeset_period = 40

    dut.pin(:tdi).drive!(0)
    dut.pin(:tdi).drive!(1)
    tester.message.should == 'pin_timingv2:1,drive,0.0,data,tdo,tms,tdi;10.0,data,tck;30.0,0,tck|compare,40.0,data,tck,tdo,tms,tdi'
  end
  
  specify 'handles multiple event types at same timing event' do
    Origen.target.temporary = -> { TimingAPITestDUT.new; OrigenLink::Test::VectorBased.new('localhost', 12_777) }
    Origen.target.load!
    tester.pinmap = 'tck, 5, tdo, 8, tms, 10, tdi, 15'
    tester.pinorder = 'tck, tdo, tms, tdi'
    tester.message = ''
    tester.set_timeset('tp0', 40)
    dut.timeset :tp0 do |t|
      t.wave :tck do |w|
        w.drive :data, at: 10
        w.drive 0, at: 30
      end
      t.wave :tdi, :tms do |w|
        w.drive :data, at: 0
      end
      t.wave :tdo do |w|
        w.drive :data, at: 30
      end
      t.wave do |w|
        w.compare :data, at: 40
      end
    end
    # temporarily force
    dut.current_timeset_period = 40

    dut.pin(:tdi).drive!(0)
    dut.pin(:tdi).drive!(1)
    tester.message.should == 'pin_timingv2:1,drive,0.0,data,tms,tdi;10.0,data,tck;30.0,0,tck;30.0,data,tdo|compare,40.0,data,tck,tdo,tms,tdi'
  end
  
end

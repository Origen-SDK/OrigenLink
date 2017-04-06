require 'spec_helper'
require 'origen_link/server/sequencer'
require 'fileutils'

describe OrigenLink::Server::Sequencer do

  before :all do
    unless File.exist?(OrigenLink::Server.gpio_dir)
      d = "#{Origen.root}/tmp/gpio"
      FileUtils.mkdir_p(d)
      OrigenLink::Server.gpio_dir = d
      make_gpio(23)
    end
  end

  def make_gpio(number)
    d = "#{OrigenLink::Server.gpio_dir}/gpio#{number}"
    FileUtils.mkdir_p(d) unless File.exist?(d)
    %w(direction value).each do |f|
      FileUtils.touch("#{d}/#{f}") unless File.exist?("#{d}/#{f}")
    end
  end

  specify "pinmap" do
    test_obj = OrigenLink::Server::Sequencer.new
    test_obj.processmessage('pin_assign:tck,23').should == 'P:'
    test_obj.pinmap['tck'].to_s.should == 'OrigenLinkPin23'
    test_obj.processmessage('pin_assign:tdo,1900').should == 'F:pin tdo gpio1900 is invalid'
    test_obj.processmessage('pin_assign:tck,23').should == 'P:'
    test_obj.pinmap['tck'].to_s.should == 'OrigenLinkPin23'
    test_obj.pinmap['tdo'].should == -1
  end

  specify "pinorder" do
    test_obj = OrigenLink::Server::Sequencer.new
    test_obj.processmessage('pin_assign:tdi,23,tdo,23,tms,23').should == 'P:'
    test_obj.processmessage('pin_patternorder:tdi,tdo,tms').should == 'P:'
    test_obj.patternorder.should == %w(tdi tdo tms)
    test_obj.patternpinindex.should == { 'tdi' => 0, 'tdo' => 1, 'tms' => 2 }
    test_obj.cycletiming[0]['events'].should == [0, 1, 2]
  end

  specify "pinformat_timing" do
    test_obj = OrigenLink::Server::Sequencer.new
    test_obj.processmessage('pin_assign:tck,23,extal,23,tdi,23,tms,23,tdo,23')
    test_obj.processmessage('pin_format:1,tck,rl').should == 'P:'
    test_obj.cycletiming[1]['drive_event_data'][1].should == ['data']
    test_obj.cycletiming[1]['drive_event_data'][3].should == ['0']

    test_obj.processmessage('pin_format:1,xtal,rh').should == 'P:'
    test_obj.cycletiming[1]['drive_event_data'][1].should == ['data']
    test_obj.cycletiming[1]['drive_event_data'][3].should == ['1']

    test_obj.processmessage('pin_format:2,tck,rl').should == 'P:'
    test_obj.cycletiming[2]['drive_event_data'][1].should == ['data']
    test_obj.cycletiming[2]['drive_event_data'][3].should == ['0']
    test_obj.cycletiming[1]['drive_event_data'][1].should == ['data']
    test_obj.cycletiming[1]['drive_event_data'][3].should == ['1']

    test_obj.processmessage('pin_timing:1,tdi,0,tms,1,tdo,2').should == 'P:'
    test_obj.cycletiming[2]['drive_event_data'][1].should == ['data']
    test_obj.cycletiming[2]['drive_event_data'][3].should == ['0']
    test_obj.cycletiming[1]['drive_event_data'][1].should == ['data']
    test_obj.cycletiming[1]['drive_event_data'][3].should == ['1']
    test_obj.cycletiming[1]['drive_event_data'][0].should == ['data']
    test_obj.cycletiming[1]['drive_event_data'][2].should == ['data']
    test_obj.cycletiming[1]['drive_event_data'][4].should == ['data']
  end

  specify "pin_timingv2" do
    test_obj = OrigenLink::Server::Sequencer.new
    test_obj.processmessage('pin_assign:tck,23,extal,23,tdi,23,tms,23,tdo,23')
    test_obj.processmessage('pin_timingv2:1,drive,5.0,data,tdo,tms,tdi;20.0,data,tck|compare,35.0,data,tck,tdo,tms,tdi').should == 'P:'
    test_obj.cycletiming[1]['drive_event_data'][5.0].should == ['data']
    test_obj.cycletiming[1]['drive_event_data'][20.0].should == ['data']
    test_obj.cycletiming[1]['compare_event_data'][35.0].should == ['data']
  
    test_obj.processmessage('pin_timingv2:2,drive,0.0,data,tdo,tms,tdi;10.0,data,tck;30.0,0,tck|compare,40.0,data,tck,tdo,tms,tdi').should == 'P:'
    test_obj.cycletiming[2]['drive_event_data'][30.0].should == ['0']
end

end

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
    d = "#{OrigenLink::Server.gpio_dir}/#{number}"
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
    test_obj.processmessage('pin_patternorder:tdi,tdo,tms').should == 'P:'
    test_obj.patternorder.should == %w(tdi tdo tms)
    test_obj.patternpinindex.should == { 'tdi' => 0, 'tdo' => 1, 'tms' => 2 }
    test_obj.cycletiming[0]['timing'].should == [%w(tdi tdo tms), [], []]
  end

  specify "pinformat_timing" do
    test_obj = OrigenLink::Server::Sequencer.new
    test_obj.processmessage('pin_format:1,tck,rl').should == 'P:'
    test_obj.cycletiming[1]['rl'].should == ['tck']
    test_obj.cycletiming[1]['rh'].should == nil

    test_obj.processmessage('pin_format:1,xtal,rh').should == 'P:'
    test_obj.cycletiming[1]['rl'].should == nil
    test_obj.cycletiming[1]['rh'].should == ['xtal']

    test_obj.processmessage('pin_format:2,tck,rl').should == 'P:'
    test_obj.cycletiming[2]['rl'].should == ['tck']
    test_obj.cycletiming[2]['rh'].should == nil
    test_obj.cycletiming[1]['rl'].should == nil
    test_obj.cycletiming[1]['rh'].should == ['xtal']

    test_obj.processmessage('pin_timing:1,tdi,0,tms,1,tdo,2').should == 'P:'
    test_obj.cycletiming[2]['rl'].should == ['tck']
    test_obj.cycletiming[2]['rh'].should == nil
    test_obj.cycletiming[1]['rl'].should == nil
    test_obj.cycletiming[1]['rh'].should == ['xtal']
    test_obj.cycletiming[1]['timing'].should == [['tdi'], ['tms'], ['tdo']]
    test_obj.cycletiming[2]['timing'].should == [[], [], []]
  end

end

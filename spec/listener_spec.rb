require 'spec_helper'

describe 'The Link Listener' do

  class LinkListenerTestDUT
    include Origen::TopLevel
    attr_accessor :write_requests, :read_requests

    def initialize
      add_reg :reg1, 0
      #sub_block :sub
      @write_requests = 0
      @read_requests = 0

      sub_block :sub, class_name: 'LinkSubBlock'
    end

    def write_register(reg, options={})
      @write_requests += 1
    end

    def read_register(reg, options={})
      @read_requests += 1
    end
  end

  class LinkSubBlock
    include Origen::Model

    def initialize
      add_reg :reg1, 0
      add_reg :reg2, 0x4 do |reg|
        reg.bits 31..16, :upper
        reg.bits 15..0, :lower
      end
    end
  end

  before :all do
    @thread = Thread.new do
      OrigenLink::Listener.run!(port: 12345)
    end
    sleep 0.2

    Origen.target.temporary = -> { LinkListenerTestDUT.new }
    Origen.target.load!
  end

  after :all do
    @thread.kill
  end

  it 'is alive' do
    r = HTTP.get("http://localhost:12345/hello_world")
    r.code.should == 200
    r.body.to_s.should == "Hello there"
  end

  it 'can see the DUT' do
    r = HTTP.get("http://localhost:12345/dut_class")
    r.code.should == 200
    r.body.to_s.should == "LinkListenerTestDUT"
  end

  it 'registers can be written' do
    dut.reg1.data.should == 0
    dut.write_requests.should == 0
    r = HTTP.post("http://localhost:12345/write_register", form: {path: 'reg1', data: 0xFFFF_FFFF})
    r.code.should == 200
    dut.reg1.data.should == 0xFFFF_FFFF
    r = HTTP.post("http://localhost:12345/write_register", form: {path: 'sub.reg1', data: 0xFF})
    r.code.should == 200
    dut.sub.reg1.data.should == 0xFF
    r = HTTP.post("http://localhost:12345/write_register", form: {path: 'sub.reg2.upper', data: 0x55})
    r.code.should == 200
    dut.sub.reg2.data.should == 0x55_0000
    r = HTTP.post("http://localhost:12345/write_register", form: {path: 'sub.reg2[7:4]', data: 0xA})
    r.code.should == 200
    dut.sub.reg2.data.should == 0x55_00A0
    r = HTTP.post("http://localhost:12345/write_register", form: {path: 'sub.reg2[3]', data: 1})
    r.code.should == 200
    dut.sub.reg2.data.should == 0x55_00A8

    dut.write_requests.should == 5
  end

  it 'registers can be read'
end

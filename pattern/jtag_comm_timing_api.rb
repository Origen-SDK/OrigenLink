Pattern.create(options={:name => "Timing_API_Test"})do
  tester.set_timeset('api_tst', 40)
  $dut.timeset :api_tst do |t|
    t.wave :tclk do |w|
      w.drive :data, at: 10
      w.drive 0, at: 30
    end
    t.wave :tdi, :tms, :tdo do |w|
      w.drive :data, at: 5
    end
    t.wave do |w|
      w.compare :data, at: 35
    end
  end
  $dut.current_timeset_period = 40

  $dut.jtag.reset
  $dut.jtag.idle
  ss "reading Halo debugger ID"
  $dut.reg(:testreg).read(0x5ba00477)
  $dut.jtag.read_dr dut.reg(:testreg), size: 32
  $dut.jtag.write_ir 0, size: 4
  ss "reading Halo JTAG ID"
  $dut.reg(:testreg).read(0x1984101d)
  $dut.jtag.read_dr dut.reg(:testreg), size: 32
end
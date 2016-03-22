Pattern.create(options={:name => "JTAG_Test"})do
  $dut.jtag.reset
  $dut.jtag.idle
  ss "reading Halo debugger ID"
  $dut.reg(:testreg).read(0x5ba00477)
  $dut.jtag.read_dr $dut.reg(:testreg), size: 32
  $dut.jtag.write_ir 0, size: 4
  ss "reading Halo JTAG ID"
  $dut.reg(:testreg).read(0x1984101d)
  $dut.jtag.read_dr $dut.reg(:testreg), size: 32
end
Pattern.create(options={:name => "JTAG_Test_Force_Fail"})do
  $dut.jtag.reset
  $dut.jtag.idle
  ss "reading Halo debugger ID - setting wrong compare value"
 #$dut.reg(:testreg).read(0x5ba00477)
  $dut.reg(:testreg).read(0x5bd00477)
  $dut.jtag.read_dr $dut.reg(:testreg), size: 32
  $dut.jtag.write_ir 0, size: 4
  ss "reading Halo JTAG ID - setting wrong compare value"
 #$dut.reg(:testreg).read(0x1984101d)
  $dut.reg(:testreg).read(0x1984101a)
  $dut.jtag.read_dr $dut.reg(:testreg), size: 32
end
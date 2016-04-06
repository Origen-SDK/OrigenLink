Pattern.create(options={:name => "JTAG_CaptureID"})do
  $dut.jtag.reset
  $dut.jtag.idle
  ss "reading default ID"
  $dut.reg(:testreg).bits(31..0).store
  default_id = tester.capture {$dut.jtag.read_dr $dut.reg(:testreg), size: 32 }
  default_id_str = default_id[0].to_s(2)
  default_id_str.reverse!
  default_id = default_id_str.to_i(2)
  puts '**************************************************'
  puts 'Captured default ID through JTAG: 0x' + default_id.to_s(16)
  puts '**************************************************'
  $dut.jtag.write_ir 0, size: 4
  ss "reading JTAG ID"
  $dut.reg(:testreg).bits(31..0).store
  jtag_id = tester.capture {$dut.jtag.read_dr $dut.reg(:testreg), size: 32 }
  jtag_id_str = jtag_id[0].to_s(2)
  jtag_id_str.reverse!
  jtag_id = jtag_id_str.to_i(2)
  puts '**************************************************'
  puts 'Captured JTAG ID: 0x' + jtag_id.to_s(16)
  puts '**************************************************'
end
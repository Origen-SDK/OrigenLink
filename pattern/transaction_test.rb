Pattern.create(options={:name => "transaction_test"})do
  $dut.jtag.reset
  $dut.jtag.idle
  ss "reading Halo debugger ID - setting correct compare value"
  result = tester.transaction do 
    $dut.reg(:testreg).read(0x5ba00477)
    $dut.jtag.read_dr $dut.reg(:testreg), size: 32
  end
  result_comment =  "transaction result: #{result}"
  ss result_comment
  
  ss "reading Halo debugger ID - setting wrong compare value"
  result = tester.transaction do
    $dut.reg(:testreg).read(0x5bd00477)
    $dut.jtag.read_dr $dut.reg(:testreg), size: 32
  end
  result_comment = "transaction result: #{result}"
  ss result_comment
end
# The target file is run before *every* Origen operation and is used to instantiate
# the runtime environment - usually this means instantiating a top-level SoC or
# IP model.
$dut = TestDut::TopLevel.new(jtag_comm_config: true, invalid_pin_number_test: true)   # Instantiate a DUT instance

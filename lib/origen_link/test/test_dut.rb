module TestDut
  class TopLevel
    include Origen::TopLevel

    def initialize(options = {})
      instantiate_pins(options)
      instantiate_registers(options)
      instantiate_sub_blocks(options)
    end

    def instantiate_pins(options = {})
	  options = {
	    jtag_comm_config:			false,
		invalid_pin_number_test:	false,
		missing_pinmap_test:		false
	  }.merge(options)
      add_pin :tclk
      add_pin :tdi
      add_pin :tdo
      add_pin :tms
      add_pin :resetb
      add_pins :port_a, size: 8
	  
  	  pin_pattern_order :tclk, :tms, :tdi, :tdo, only: true if options[:jtag_comm_config]

	  #if tester.link? #.to_s == 'OrigenLink::VectorBased'
	  if tester.to_s == 'OrigenLink::VectorBased'
	    if options[:invalid_pin_number_test]
	      tester.pinmap = 'tclk,119,tms,1900,tdi,116,tdo,124'		  
		else
	      tester.pinmap = 'tclk,119,tms,6,tdi,116,tdo,124' unless options[:missing_pinmap_test]
		end
		tester.pinorder = 'tclk,tms,tdi,tdo'
	  end
    end

    def instantiate_registers(options = {})
	  reg :testreg, 0 do |reg|
	    reg.bits 31..0,		:value
	  end
    end

    def instantiate_sub_blocks(options = {})
    end
  end
end
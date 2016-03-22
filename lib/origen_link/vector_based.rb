module OrigenLink
  # OrigenLink::VectorBased
  #   This class is meant to be used for live silicon debug.  Vector data that Origen
  #   generates is intercepted and sent to a debug device (typically will be a Udoo
  #   Neo - www.udoo.org).  The debug device can be any device that is able to serve
  #   a TCP socket, recieve and interpret the command set used by this class and send
  #   the expected responses.
  #
  # Integration instructions
  #   Set the pin map (must be done first) and pin order
  #     if tester.link?
  #	    tester.pinmap = 'tclk,26,tms,19,tdi,16,tdo,23'
  #		tester.pinorder = 'tclk,tms,tdi,tdo'
  #     end
  #
  #   Set Origen to only generate vectors for pins in the pinmap (order should match)
  #  	  pin_pattern_order :tclk, :tms, :tdi, :tdo, only: true if tester.link?
  #
  #   At the beginning of the Startup method add this line
  #	  tester.initialize_pattern if tester.link?
  #
  #   At the end of the Shutdown method add this line
  #     tester.finalize_pattern if tester.link?
  #
  #   Create a link environment with the IP address and socket number of a link server
  #     $tester = OrigenLink::VectorBased.new('192.168.0.2', 12777)
  class VectorBased
    #include OrigenTesters::VectorBasedTester
	
	#these attributes are exposed for testing purposes, a user would not need to read them
	attr_reader :fail_count, :vector_count, :total_comm_time, :total_connect_time, :total_xmit_time, :total_recv_time, :total_packets, :vector_repeatcount, :tsets_programmed
	
	def initialize(address, port)
	  @address = address
	  @port = port
	  @fail_count = 0
	  @vector_count = 0
	  @previous_vectordata = ''
	  @previous_tset = ''
	  @vector_repeatcount = 0
	  @total_comm_time = 0
	  @total_connect_time = 0
	  @total_xmit_time = 0
	  @total_recv_time = 0
	  @total_packets = 0
	  @max_packet_time = 0
	  @max_receive_time = 0
	  @tsets_programmed = {}
	  @tset_count = 1
	end
	
	# push_vector
	#   This method intercepts vector data from Origen, removes white spaces and compresses repeats
	def push_vector(options)
	  programmed_data = options[:pin_vals].gsub(/\s+/, '')
      tset = options[:timeset].name
	  if @vector_count > 0
	    #compressing repeats as we go
		if (programmed_data == @previous_vectordata) and (@previous_tset == tset)
		  @vector_repeatcount += 1
		else
		  #all repeats of the previous vector have been counted
		  #time to flush.  Don't panic though!  @previous_vectordata
		  #is what gets flushed.  programmed_data is passed as an
		  #arg to be set as the new @previous_vectordata
          self.flush_vector(programmed_data, tset)
		end
	  else
	    # if this is the first vector of the pattern, insure variables are initialized
		@previous_vectordata = programmed_data
		@previous_tset = tset
		@vector_repeatcount = 1
	  end #if vector_count > 0
	  @vector_count += 1
	end
	
	# flush_vector
	#   Just as the name suggests, this method "flushes" a vector.  This is necessary because
	#   of repeat compression (a vector isn't sent until different vector data is encountered)
	#
	#   Don't forget to flush when you're in debug mode.  Otherwise, the last vector of a
	#   write command won't be sent to the server.
	def flush_vector(programmed_data = '', tset = '')
	  if @vector_repeatcount > 1
		repeat_prefix = "repeat#{@vector_repeatcount.to_s},"
	  else
		repeat_prefix = ''
	  end
	  if @tsets_programmed[@previous_tset]
	    tset_prefix = "tset#{@tsets_programmed[@previous_tset]},"
	  else
	    tset_prefix = ''
	  end
	  response = self.send_cmd('pin_cycle', tset_prefix + repeat_prefix + @previous_vectordata)
	  microcode response
	  unless response.chr == 'P'
	    microcode 'E:' + @previous_vectordata + ' //expected data for previous vector'
		@fail_count += 1
	  end
	  @vector_repeatcount = 1
	  @previous_vectordata = programmed_data
	  @previous_tset = tset
	end
	
	# initialize_pattern
	#   At some point in the future this intialization should be done behind the
	#   scenes without requiring the user to add code to the controller.
	#
	#   This method sets initializes variables at the start of a pattern.
	#   it should be called from the Startup method of the dut controller.
	def initialize_pattern
	  @fail_count = 0
	  @vector_count = 0
	  
	  @total_packets = 0
	  @total_comm_time = 0
	  @total_connect_time = 0
	  @total_xmit_time = 0
	  @total_recv_time = 0
	  
	  if @pinmap.nil?
        Origen.log.error('pinmap has not been setup, use tester.pinmap= to initialize a pinmap')
      else
	    Origen.log.info('executing pattern with pinmap:' + @pinmap.to_s)
      end
    end
	
	# finalize_pattern
	#   At some point in the future this finalization should be done behind the scenes.
	#
	#   This method flushes the final vector.  Then, it logs success or failure of the
	#   pattern execution along with execution time information.
	def finalize_pattern(programmed_data = '')
	  self.flush_vector(programmed_data)
	  if @fail_count == 0
	    Origen.log.success("PASS - pattern execution passed (#{@vector_count} vectors pass)")
      else
	    Origen.log.error("FAIL - pattern execution failed (#{@fail_count} failures)")
      end
      #for debug, report communication times
      Origen.log.info("total communication time: #{@total_comm_time}")
      Origen.log.info("total connect time: #{@total_connect_time}")
      Origen.log.info("total transmit time: #{@total_xmit_time}")
      Origen.log.info("total receive time: #{@total_recv_time}")
      Origen.log.info("total packets: #{@total_packets}")
      Origen.log.info("total time per packet: #{@total_comm_time/@total_packets}")
      Origen.log.info("connect time per packet: #{@total_connect_time/@total_packets}")
      Origen.log.info("transmit time per packet: #{@total_xmit_time/@total_packets}")
      Origen.log.info("receive time per packet: #{@total_recv_time/@total_packets}")
	  Origen.log.info("max packet time: #{@max_packet_time}")
	  Origen.log.info("max duration command - " + @longest_packet)
	  Origen.log.info("max receive time: #{@max_receive_time}")
	end
	
	# to_s
	#   returns 'Origen::VectorBased'
	#
	#   This method at the moment is used for implementing code that runs only if the 
	#   environment is set to link vector based.  tester.link? will be used once the testers
	#   plug in supports the method link?.
	def to_s
	  'OrigenLink::VectorBased'
	end
	
	# link?
	#   returns true.
	#
	#   This method indicates to user code that link is the tester environment.
	def link?
	  true
	end
	
	# pinmap=
	#   This method is used to setup the pin map on the debugger device.
	#   The argument should be a string with <pin name>, <gpio #>, <pin name>
	#   <gpio #>, etc
	#
	#   example:
	#     tester.pinmap = 'tclk,26,tms,19,tdi,16,tdo,23'
	def pinmap=(pinmap)
	  @pinmap = pinmap.gsub(/\s+/, '')
	  response = self.send_cmd('pin_assign', @pinmap)
	  self.setup_cmd_response_logger('pin_assign', response)
	end
	
	# pinorder=
	#   This method is used to setup the pin order on the debugger device.
	#   The pin order will indicate the order that pin data appears in vector 
	#   data.
	#
	#   This is a duplicate of pattern_pin_order and can be handled behind the
	#   scenes in the future.
	#
	#   example:
	#     tester.pinorder = 'tclk,tms,tdi,tdo'
	def pinorder=(pinorder)
	  @pinorder = pinorder.gsub(/\s+/, '')
	  response = self.send_cmd('pin_patternorder', @pinorder)
	  self.setup_cmd_response_logger('pin_patternorder', response)
	end
	
	# pinformat=
	#   This method is used to setup the pin clock format on the debugger device.
	#   The supported formats are rl and rh
	#
	#   example:
	#     tester.pinformat = 'func_25mhz,tclk,rl'
	def pinformat=(pinformat)
	  @pinformat = replace_tset_name_w_number(pinformat.gsub(/\s+/, ''))
	  response = self.send_cmd('pin_format', @pinformat)
	  self.setup_cmd_response_logger('pin_format', response)
	end

	# pintiming=
	#   This method is used to setup the pin timing on the debugger device.
	#   Timing is relative to the rise and fall of a clock
	#
	#   timing value:         0   1   2
	#   clock waveform:      ___/***\___
	#
	#   example:
	#     tester.pintiming = 'func_25mhz,tms,0,tdi,0,tdo,1'
	def pintiming=(pintiming)
	  @pintiming = replace_tset_name_w_number(pintiming.gsub(/\s+/, ''))
	  response = self.send_cmd('pin_timing', @pintiming)
	  self.setup_cmd_response_logger('pin_timing', response)
	end

	# replace_tset_name_w_number(csl)
	#  This method is used by pinformat= and pintiming=
	#  This method receives a comma separated list of arguments
	#  the first of which is a timeset name.  A comma
	#  separated list is returned with the timeset name replaced
	#  by it's lookup number.  If it is a new timset, a lookup
	#  number is associated with the name.
	def replace_tset_name_w_number(csl)
      args = csl.split(',')
	  args[0] = self.get_tset_number(args[0])
	  args.join(',')
	end
	
	# get_tset_number(name)
	#   This method returns the test number associated with the
	#   passed in tset name.  If the name is unknown a new lookup
	#   number is returned.
	def get_tset_number(name)
	  if not @tsets_programmed.key?(name)
	    @tsets_programmed[name] = @tset_count
		@tset_count += 1
	  end
      @tsets_programmed[name]
	end
	
  end
end

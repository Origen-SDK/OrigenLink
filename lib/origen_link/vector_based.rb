require 'origen_testers'
require 'origen_link/server_com'
require 'origen_link/callback_handlers'
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
    include OrigenTesters::VectorBasedTester
    include ServerCom

    # these attributes are exposed for testing purposes, a user would not need to read them
    attr_reader :fail_count, :vector_count, :total_comm_time, :total_connect_time, :total_xmit_time
    attr_reader :total_recv_time, :total_packets, :vector_repeatcount, :tsets_programmed, :captured_data

    def initialize(address, port, options = {})
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
      @store_pins = []
      @captured_data = []
      # A tester seems to be unable to register as a callback handler, so for now instantiating a
      # dedicated object to implement the handlers related to this tester
      CallbackHandlers.new
    end

    # push_vector
    #   This method intercepts vector data from Origen, removes white spaces and compresses repeats
    def push_vector(options)
      programmed_data = options[:pin_vals].gsub(/\s+/, '')
      unless options[:timeset]
        puts 'No timeset defined!'
        puts 'Add one to your top level startup method or target like this:'
        puts '$tester.set_timeset("nvmbist", 40)   # Where 40 is the period in ns'
        exit 1
      end
      tset = options[:timeset].name
      if @vector_count > 0
        # compressing repeats as we go
        if (programmed_data == @previous_vectordata) && (@previous_tset == tset) && @store_pins.empty?
          @vector_repeatcount += 1
        else
          # all repeats of the previous vector have been counted
          # time to flush.  Don't panic though!  @previous_vectordata
          # is what gets flushed.  programmed_data is passed as an
          # arg to be set as the new @previous_vectordata
          flush_vector(programmed_data, tset)
        end
      else
        # if this is the first vector of the pattern, insure variables are initialized
        @previous_vectordata = programmed_data
        @previous_tset = tset
        @vector_repeatcount = 1
      end # if vector_count > 0
      @vector_count += 1
    end

    # Capture a vector
    #
    # This method applies a store vector request to the previous vector, note that is does
    # not actually generate a new vector.
    #
    # The captured data is added to the captured_data array.
    #
    # This method is indended to be used by pin drivers, see the #capture method for the application
    # level API.
    #
    # @example
    #   $tester.cycle                # This is the vector you want to capture
    #   $tester.store                # This applies the store request
    def store(*pins)
      options = pins.last.is_a?(Hash) ? pins.pop : {}
      fail 'The store is not implemented yet on Link'
    end

    # Capture the next vector generated
    #
    # This method applies a store request to the next vector to be generated,
    # note that is does not actually generate a new vector.
    #
    # The captured data is added to the captured_data array.
    #
    # This method is indended to be used by pin drivers, see the #capture method for the application
    # level API.
    #
    # @example
    #   tester.store_next_cycle
    #   tester.cycle                # This is the vector that will be captured
    def store_next_cycle(*pins)
      options = pins.last.is_a?(Hash) ? pins.pop : {}
      flush_vector
      @store_pins = pins
    end

    # Capture any store data within the given block, return it and then internally clear the tester's
    # capture memory.
    #
    # @example
    #
    #   v = tester.capture do
    #     my_reg.store!
    #   end
    #   v      # => Data value read from my_reg on the DUT
    def capture(*args)
      if block_given?
        yield
        d = @captured_data
        @captured_data = []
        d
      else
        # On other testers capture is an alias of store
        store(*args)
      end
    end

    # flush_vector
    #   Just as the name suggests, this method "flushes" a vector.  This is necessary because
    #   of repeat compression (a vector isn't sent until different vector data is encountered)
    #
    #   Don't forget to flush when you're in debug mode.  Otherwise, the last vector of a
    #   write command won't be sent to the server.
    def flush_vector(programmed_data = '', tset = '')
      # prevent server crash when vector_flush is used during debug
      unless @previous_vectordata == ''
        if @vector_repeatcount > 1
          repeat_prefix = "repeat#{@vector_repeatcount},"
        else
          repeat_prefix = ''
        end
        if @tsets_programmed[@previous_tset]
          tset_prefix = "tset#{@tsets_programmed[@previous_tset]},"
        else
          tset_prefix = ''
        end

        response = send_cmd('pin_cycle', tset_prefix + repeat_prefix + @previous_vectordata)
        unless @store_pins.empty?
          msg = "  (Captured #{@store_pins.map(&:name).join(', ')})\n"
          capture_data(response)
          response.strip!
          response += msg
        end
        microcode response

        unless response.chr == 'P'
          # TODO: Put this back with an option to disable, based on a serial or parallel interface being used
          # microcode 'E:' + @previous_vectordata + ' //expected data for previous vector'
          @fail_count += 1
        end
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
      flush_vector(programmed_data)
      # for debug, report communication times
      Origen.log.debug("total communication time: #{@total_comm_time}")
      Origen.log.debug("total connect time: #{@total_connect_time}")
      Origen.log.debug("total transmit time: #{@total_xmit_time}")
      Origen.log.debug("total receive time: #{@total_recv_time}")
      Origen.log.debug("total packets: #{@total_packets}")
      Origen.log.debug("total time per packet: #{@total_comm_time / @total_packets}")
      Origen.log.debug("connect time per packet: #{@total_connect_time / @total_packets}")
      Origen.log.debug("transmit time per packet: #{@total_xmit_time / @total_packets}")
      Origen.log.debug("receive time per packet: #{@total_recv_time / @total_packets}")
      Origen.log.debug("max packet time: #{@max_packet_time}")
      Origen.log.debug("max duration command - #{@longest_packet}")
      Origen.log.debug("max receive time: #{@max_receive_time}")
      if @fail_count == 0
        # Origen.log.success("PASS - pattern execution passed (#{@vector_count} vectors pass)")
        Origen.app.stats.report_pass
      else
        # Origen.log.error("FAIL - pattern execution failed (#{@fail_count} failures)")
        Origen.app.stats.report_fail
      end
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

    # pinmap=
    #   This method is used to setup the pin map on the debugger device.
    #   The argument should be a string with <pin name>, <gpio #>, <pin name>
    #   <gpio #>, etc
    #
    #   example:
    #     tester.pinmap = 'tclk,26,tms,19,tdi,16,tdo,23'
    def pinmap=(pinmap)
      @pinmap = pinmap.gsub(/\s+/, '')
      response = send_cmd('pin_assign', @pinmap)
      setup_cmd_response_logger('pin_assign', response)
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
      response = send_cmd('pin_patternorder', @pinorder)
      setup_cmd_response_logger('pin_patternorder', response)
    end

    # pinformat=
    #   This method is used to setup the pin clock format on the debugger device.
    #   The supported formats are rl and rh
    #
    #   example:
    #     tester.pinformat = 'func_25mhz,tclk,rl'
    def pinformat=(pinformat)
      @pinformat = replace_tset_name_w_number(pinformat.gsub(/\s+/, ''))
      response = send_cmd('pin_format', @pinformat)
      setup_cmd_response_logger('pin_format', response)
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
      response = send_cmd('pin_timing', @pintiming)
      setup_cmd_response_logger('pin_timing', response)
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
      args[0] = get_tset_number(args[0])
      args.join(',')
    end

    # get_tset_number(name)
    #   This method returns the test number associated with the
    #   passed in tset name.  If the name is unknown a new lookup
    #   number is returned.
    def get_tset_number(name)
      unless @tsets_programmed.key?(name)
        @tsets_programmed[name] = @tset_count
        @tset_count += 1
      end
      @tsets_programmed[name]
    end

    private

    def capture_data(response)
      if @store_pins.size > 1
        fail 'Data capture on multiple pins is not implemented yet'
      else
        captured_data[0] ||= 0
        captured_data[0] = (captured_data[0] << 1) | extract_value(response, @store_pins[0])
        @store_pins = []
      end
    end

    def extract_value(response, pin)
      v = response[index_of(pin) + 2]
      if v == '`'
        1
      elsif v == '.'
        0
      else
        fail "Failed to extract value for pin #{pin.name}, character in response is: #{v}"
      end
    end

    # Returns the vector index (position) of the given pin
    def index_of(pin)
      i = @pinorder.split(',').index(pin.name.to_s)
      unless i
        fail "Data capture of pin #{pin.name} has been requested, but it has not been included in the Link pinmap!"
      end
      i
    end
  end
end

require 'origen_testers'
require 'origen_link/server_com'
require 'origen_link/capture_support'
require 'origen_link/configuration_commands'
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
  #        tester.pinmap = 'tclk,26,tms,19,tdi,16,tdo,23'
  #        tester.pinorder = 'tclk,tms,tdi,tdo'
  #     end
  #
  #   Set Origen to only generate vectors for pins in the pinmap (order should match)
  #        pin_pattern_order :tclk, :tms, :tdi, :tdo, only: true if tester.link?
  #
  #   At the beginning of the Startup method add this line
  #      tester.initialize_pattern if tester.link?
  #
  #   At the end of the Shutdown method add this line
  #     tester.finalize_pattern if tester.link?
  #
  #   Create a link environment with the IP address and socket number of a link server
  #     $tester = OrigenLink::VectorBased.new('192.168.0.2', 12777)
  class VectorBased
    include OrigenTesters::VectorBasedTester
    include ServerCom
    include CaptureSupport
    include ConfigurationCommands

    # these attributes are exposed for testing purposes, a user would not need to read them
    attr_reader :fail_count, :vector_count, :total_comm_time, :total_connect_time, :total_xmit_time
    attr_reader :total_recv_time, :total_packets, :vector_repeatcount, :tsets_programmed, :captured_data
    attr_reader :vector_batch, :store_pins_batch, :comment_batch

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
      @vector_batch = []
      @store_pins_batch = {}
      @comment_batch = {}
      @batch_vectors = true
    end

    # push_comment
    #   This method intercepts comments so they can be correctly placed in the output file
    #   when vector batching is used
    def push_comment(msg)
      if @batch_vectors
        key = @vector_batch.length
        if @comment_batch.key?(key)
          @comment_batch[key] = @comment_batch[key] + "\n" + msg
        else
          @comment_batch[key] = msg
        end
      else
        microcode msg
      end
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

        if @batch_vectors
          @vector_batch << 'pin_cycle:' + tset_prefix + repeat_prefix + @previous_vectordata
          # store capture pins for batch processing
          unless @store_pins.empty?
            @store_pins_batch[@vector_batch.length - 1] = @store_pins
          end
        else
          process_vector_response(send_cmd('pin_cycle', tset_prefix + repeat_prefix + @previous_vectordata))
        end

        # make sure that only requested vectors are stored when batching is enabled
        @store_pins = []
      end

      @vector_repeatcount = 1
      @previous_vectordata = programmed_data
      @previous_tset = tset
    end

    # synchronize
    #   This method will synchronize the DUT state with Origen.  All generated
    #   vectors are sent to the DUT for execution and the responses are processed
    def synchronize(output_file = '')
      flush_vector
      if @batch_vectors
        process_response(send_batch(@vector_batch), output_file)
      end
      @vector_batch = []
      @store_pins_batch.clear
      @comment_batch.clear
    end

    # process_response
    #   This method will process a server response.  Send log info to the output,
    #   keep track of fail count and captured data
    def process_response(response, output_file = '')
      if response.is_a?(Array)
        # if called from finalize_pattern -> synchronize, open the output_file and store results
        output_obj = nil
        output_obj = File.open(output_file, 'a+') unless output_file == ''

        # in case there were only comments and no vectors, place comments (if any)
        microcode @comment_batch[0] if response.size == 0

        response.each_index do |index|
          # restore store pins state for processing
          if @store_pins_batch.key?(index)
            @store_pins = @store_pins_batch[index]
          else
            @store_pins = []
          end
          process_vector_response(response[index], output_obj)
          if @comment_batch.key?(index)
            if output_file == ''
              microcode @comment_batch[index]
            else
              # get the header placed correctly, the below code doesn't work
              # if index == response.length - 1
              #   output_obj.puts 'last comment'
              #   output_obj.lineno = 0
              # end
              output_obj.puts(@comment_batch[index])
            end
          end
        end
        output_obj.close unless output_file == ''
      else
        process_vector_response(response)
      end
    end

    # process_vector_response
    #   This method exists to prevent code duplication when handling an array of
    #   batched responses versus a single response string.
    def process_vector_response(vector_response, output_obj = nil)
      unless @store_pins.empty?
        msg = "  (Captured #{@store_pins.map(&:name).join(', ')})\n"
        capture_data(vector_response)
        vector_response.strip!
        vector_response += msg
      end
      vector_cycles = vector_response.split(/\s+/)
      expected_msg = ''
      expected_msg = ' ' + vector_cycles.pop if vector_cycles[vector_cycles.length - 1] =~ /Expected/
      prepend = ''
      if output_obj.nil?
        vector_cycles.each do |cycle|
          microcode prepend + cycle + expected_msg
          prepend = ' :'
        end
      else
        vector_cycles.each do |cycle|
          output_obj.puts(prepend + cycle + expected_msg)
          prepend = ' :'
        end
      end

      unless vector_response.chr == 'P'
        # TODO: Put this back with an option to disable, based on a serial or parallel interface being used
        # microcode 'E:' + @previous_vectordata + ' //expected data for previous vector'
        @fail_count += 1
      end
    end

    # initialize_pattern
    #   This method sets initializes variables at the start of a pattern.
    #   it is called automatically when pattern generation starts.
    def initialize_pattern
      @fail_count = 0
      @vector_count = 0
      @vector_batch.delete_if { true }
      @store_pins_batch.clear
      @comment_batch.clear

      @total_packets = 0
      @total_comm_time = 0
      @total_connect_time = 0
      @total_xmit_time = 0
      @total_recv_time = 0

      if @pinmap.nil?
        Origen.log.error('pinmap has not been setup, use tester.pinmap= to initialize a pinmap')
      else
        Origen.log.debug('executing pattern with pinmap:' + @pinmap.to_s)
      end
    end

    # finalize_pattern
    #   This method flushes the final vector.  Then, it logs success or failure of the
    #   pattern execution along with execution time information.
    def finalize_pattern(output_file)
      Origen.log.debug('Pattern generation completed. Sending all stored vector data')
      synchronize(output_file)
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

    # transaction
    #   returns true/false indicating whether the transaction passed
    #   true = pass
    #   false = fail
    #
    # TODO: capture transaction vector data and response for use in debug
    #
    # if !tester.transaction {dut.reg blah blah}
    #   puts 'transaction failed'
    # end
    def transaction
      if block_given?
        synchronize
        transaction_fail_count = @fail_count
        yield
        synchronize
        transaction_fail_count = @fail_count - transaction_fail_count
        if transaction_fail_count == 0
          true
        else
          false
        end
      else
        true
      end
    end
  end
end

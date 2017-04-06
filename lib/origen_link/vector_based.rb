require 'etc'
require 'origen_testers'
require 'origen_link/server_com'
require 'origen_link/capture_support'
require 'origen_link/configuration_commands'
require 'origen_link/callback_handlers'
module OrigenLink
  # OrigenLink::VectorBased
  #   This class describes the OrigenLink app plug-in.  Vector data that Origen
  #   generates is intercepted and sent to a debug device (typically will be a Udoo
  #   Neo - www.udoo.org).  The debug device can be any device that is able to serve
  #   a TCP socket, recieve and interpret the command set used by this class and send
  #   the expected responses.
  #
  class VectorBased
    include OrigenTesters::VectorBasedTester
    include ServerCom
    include CaptureSupport
    include ConfigurationCommands

    # The number of cycles that fail
    attr_reader :fail_count
    # The number of vector cycles generated
    attr_reader :vector_count
    # The accumulated total time spent communicating with the server
    attr_reader :total_comm_time
    # The accumulated total time spent establishing the server connection
    attr_reader :total_connect_time
    # The accumulated total time spent transmitting to the server app
    attr_reader :total_xmit_time
    # The accumulated total time spent receiving from the server app
    attr_reader :total_recv_time
    # The accumulated total number of packets sent to the server
    attr_reader :total_packets
    # The accumulated number of times push_vector was called with the present tset and pin info
    attr_reader :vector_repeatcount
    # The look up of programmed tsets.  Names are converted to a unique number identifier
    attr_reader :tsets_programmed
    # Data captured using tester.capture
    attr_reader :captured_data
    # Array of vectors waiting to be sent to the sever
    attr_reader :vector_batch
    # Used with capture
    attr_reader :store_pins_batch
    # Array of comments received through push_comment
    attr_reader :comment_batch
    # The name of the user running OrigenLink
    attr_reader :user_name
    # Indicates that communication has been initiated with the server
    attr_reader :initial_comm_sent

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
      @tsets_warned = {}
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
      @pattern_link_messages = []
      @pattern_comments = {}
      @user_name = Etc.getlogin
      @initial_comm_sent = false
      @initial_vector_pushed = false
      @pinorder = ''
      @pinmap_hash = {}
      @batched_setup_cmds = []

      # check the server version against the plug-in version
      response = send_cmd('version', '')
      response = 'Error' if response.nil?	# prevent run time error in regression tests
      response.chomp!
      server_version = response.split(':')[1]
      server_version = '?.?.? - 0.2.0 or earlier' if response =~ /Error/
      app_version = Origen.app(:origen_link).version
      Origen.log.info("Plug-in link version: #{app_version}, Server link version: #{server_version}")
      unless app_version == server_version
        Origen.log.warn('Server version and plug-in link versions do not match')
      end
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
        pattern_key = @pattern_link_messages.length + key
        @pattern_comments[pattern_key] = @comment_batch[key]
      else
        microcode msg
      end
    end

    # ordered_pins(options = {})
    #   expand pin groups to their component pins after the pin ordering is completed
    #   OrigenLink always operates on individual pins.  This saves other methods
    #   from each needing to handle pins and/or groups of pins.
    def ordered_pins(options = {})
      result = super
      groups = []
      result.each { |p| groups << p if p.size > 1 }
      groups.each do |group|
        # locate this group in the result array
        i = result.index(group)
        result.delete_at(i)
        dut.pins(group.id).map.each do |sub_pin|
          result.insert(i, sub_pin)
          i += 1
        end
      end

      if @pinmap.nil?
        # create the pinmap if pin metadata was provided
        pinarr = []
        result.each do |pin|
          if pin.meta.key?(:link_io)
            pinarr << pin.name.to_s
            pinarr << pin.meta[:link_io].to_s
          end
        end
        self.pinmap = pinarr.join(',') unless pinarr.size == 0
      end

      result
    end

    # fix_ordered_pins(options)
    #   This method is called the first time push_vector is called.
    #
    #   This method will create the pinmap from pin meta data if needed.
    #
    #   This method will remove any pin data that doesn't correspond
    #   to a pin in the link pinmap and remove those pins from the
    #   @ordered_pins_cache to prevent them from being rendered
    #   on the next cycle.
    #   This will prevent unwanted behavior.  The link server
    #   expects only pin data for pins in the pinmap.
    def fix_ordered_pins(options)
      # remove non-mapped pins from the ordered pins cache - prevents them appearing in future push_vector calls
      orig_size = @ordered_pins_cache.size
      @ordered_pins_cache.delete_if { |p| !@pinmap_hash[p.name.to_s] }
      Origen.log.debug('OrigenLink removed non-mapped pins from the cached pin order array') unless orig_size == @ordered_pins_cache.size
      # update pin values for the current  push_vector call
      vals = []
      @ordered_pins_cache.each { |p| vals << p.to_vector }
      options[:pin_vals] = vals.join('')
      options
    end

    # push_vector
    #   This method intercepts vector data from Origen, removes white spaces and compresses repeats
    def push_vector(options)
      unless @initial_vector_pushed
        if @pinmap.nil?
          Origen.log.error('OrigenLink: pinmap has not been setup, use tester.pinmap= to initialize a pinmap')
        else
          Origen.log.debug('OrigenLink: executing pattern with pinmap:' + @pinmap.to_s)
        end

        # remove pins not in the link pinmap
        options = fix_ordered_pins(options)

        # now send any configuration commands that were saved prior to pinmap setup (clears all server configs)
        @batched_setup_cmds.each do |cmd|
          response = send_cmd(cmd[0], cmd[1])
          setup_cmd_response_logger(cmd[0], response)
        end

        @initial_vector_pushed = true
      end
      set_pinorder if @pinorder == ''
      programmed_data = options[:pin_vals].gsub(/\s+/, '')
      unless options[:timeset]
        puts 'No timeset defined!'
        puts 'Add one to your top level startup method or target like this:'
        puts 'tester.set_timeset("nvmbist", 40)   # Where 40 is the period in ns'
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
          # The hash of programmed tsets does not contain this tset
          # Check the timing api to see if there is timing info there
          # and send the timing info to the link server
          if dut.respond_to?(:timeset)
            tset_prefix = process_timeset(tset)
          else
            tset_warning(tset)
            tset_prefix = ''
          end
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
      msg = ''
      unless @store_pins.empty?
        msg = "  (Captured #{@store_pins.map(&:name).join(', ')})\n"
        capture_data(vector_response)
        vector_response.strip!
        # vector_response += msg
      end
      vector_cycles = vector_response.split(/\s+/)
      expected_msg = ''
      expected_msg = ' ' + vector_cycles.pop if vector_cycles[vector_cycles.length - 1] =~ /Expected/
      pfstatus = vector_cycles[0].chr
      vector_cycles[0] = vector_cycles[0].byteslice(2, vector_cycles[0].length - 2)

      vector_cycles.each do |cycle|
        thiscyclefail = false
        bad_pin_data = false
        if pfstatus == 'F'
          # check to see if this cycle failed
          0.upto(cycle.length - 1) do |index|
            bad_pin_data = true if (cycle[index] == 'W')
            thiscyclefail = true if (cycle[index] == 'H') && (expected_msg[expected_msg.length - cycle.length + index] == 'L')
            thiscyclefail = true if (cycle[index] == 'L') && (expected_msg[expected_msg.length - cycle.length + index] == 'H')
          end
        end
        if thiscyclefail
          expected_msg_prnt = expected_msg
          prepend = 'F:'
        else
          expected_msg_prnt = ''
          prepend = 'P:'
        end
        if bad_pin_data
          expected_msg_prnt = ' ' + 'W indicates no operation, check timeset definition'
          prepend = 'F:'
        end

        if output_obj.nil?
          microcode prepend + cycle + expected_msg_prnt + msg
        else
          output_obj.puts(prepend + cycle + expected_msg_prnt + msg)
        end
      end

      unless vector_response.chr == 'P'
        # TODO: Put this back with an option to disable, based on a serial or parallel interface being used
        # microcode 'E:' + @previous_vectordata + ' //expected data for previous vector'
        @fail_count += 1
      end
    end

    # initialize_pattern
    #   This method initializes variables at the start of a pattern.
    #   It is called automatically when pattern generation starts.
    def initialize_pattern
      @fail_count = 0
      @vector_count = 0
      @vector_batch.delete_if { true }
      @store_pins_batch.clear
      @comment_batch.clear
      @pattern_link_messages.delete_if { true }
      @pattern_comments.clear

      @total_packets = 0
      @total_comm_time = 0
      @total_connect_time = 0
      @total_xmit_time = 0
      @total_recv_time = 0

      # moved to push_vector to allow auto-pinmap
      # if @pinmap.nil?
      #   Origen.log.error('OrigenLink: pinmap has not been setup, use tester.pinmap= to initialize a pinmap')
      # else
      #   Origen.log.debug('OrigenLink: executing pattern with pinmap:' + @pinmap.to_s)
      # end
    end

    # finalize_pattern
    #   This method flushes the final vector.  Then, it logs success or failure of the
    #   pattern execution along with execution time information.
    def finalize_pattern(output_file)
      Origen.log.debug('Pattern generation completed. Sending all stored vector data')
      synchronize(output_file)
      send_cmd('', 'session_end')
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
      commands_file = Origen.app.current_job.output_file.split('.')[0] + '_link_cmds.txt'
      File.open(commands_file, 'w') do |file|
        file.puts("pin_assign:#{@pinmap}")
        file.puts("pin_patternorder:#{@pinorder}")
        @pattern_link_messages.each_index do |index|
          file.puts(@pattern_link_messages[index])
          file.puts(@pattern_comments[index]) if @pattern_comments.key?(index)
        end
        file.puts(':session_end')
      end
    end

    # to_s
    #   returns 'OrigenLink::VectorBased'
    #
    #   No longer a use for this.  Use tester.link?
    def to_s
      'OrigenLink::VectorBased'
    end

    # transaction
    #   returns true/false indicating whether the transaction passed
    #   true = pass
    #   false = fail
    #
    # @example
    #   if !tester.transaction {dut.reg blah blah}
    #     puts 'transaction failed'
    #   end
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

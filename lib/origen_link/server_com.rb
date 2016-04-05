module OrigenLink
  module ServerCom
    # send_cmd(cmdstr, argstr)
    #   cmdstr is a valid command.  <category>_<command>
    #     Ex: 'pin_assign'
    #   argstr is a valid comma separated, no white space argument string.
    #     Ex: 'tclk,26,tms,19,tdi,16,tdo,23'
    #
    #   returns: response from server
    #
    #   This method connects to the socket being served by the debugger, sends
    #   the command and arguments separated by a semicolon (Ex: 'pin_cycle:110H'),
    #   then waits for a response.  The response is returned to the caller.
    #
    #   In addition, this method also keeps track of time elapsed transfering data
    #   and waiting for a response.
    def send_cmd(cmdstr, argstr)
      # objects have to be created outside of the block
      # to be accessible outside of the block
      t2 = 0
      t3 = 0
      t4 = 0
      t5 = 0
      response = ''
      t1 = Time.now

      # open a connection to the server, send the command and wait for a response
      TCPSocket.open(@address, @port) do |link|
        t2 = Time.now
        link.write(cmdstr + ':' + argstr + "\n\n")
        t3 = Time.now
        response = link.gets
        t4 = Time.now
      end

      t5 = Time.now
      @total_comm_time += (t5 - t1)
      if @max_packet_time < (t5 - t1)
        @max_packet_time = (t5 - t1)
        @longest_packet = cmdstr + ':' + argstr
      end
      @total_connect_time += (t2 - t1)
      @total_xmit_time += (t3 - t2)
      @total_recv_time += (t4 - t3)
      @max_receive_time = (t4 - t3) if @max_receive_time < (t4 - t3)
      @total_packets += 1
      Origen.log.error 'nil response from server (likely died) for command(' + cmdstr + ':' + argstr + ')' if response.nil?
      response    # ensure the response is passed along
    end

    def send_batch(vector_batch)
      t2 = 0
      t3 = 0
      t4 = 0
      t5 = 0
      response = []
      t1 = Time.now
      TCPSocket.open(@address, @port) do |link|
        t2 = Time.now
        vector_batch_str = vector_batch.join("\n") + "\n\n"
        link.write(vector_batch_str)
        t3 =  Time.now
        while line = link.gets
          response << line.chomp
        end
        t4 = Time.now
      end
      t5 = Time.now
      @total_comm_time += (t5 - t1)
      @total_connect_time += (t2 - t1)
      @total_xmit_time += (t3 - t2)
      @total_recv_time += (t4 - t3)
      @max_receive_time = (t4 - t3) if @max_receive_time < (t4 - t3)
      @total_packets += 1
      response
    end

    # setup_cmd_response_logger
    #   There are several setup commands that initialize the debugger device with
    #   information about how to interact with the dut.  All of the setup commands
    #   return pass or fail.  This method exists so that the code doesn't have to
    #   be duplicated by every setup method.
    def setup_cmd_response_logger(command, response)
      if !response.nil?
        # if the server died (which hopefully it never will) response is nil
        case response.chr
        when 'P'
          Origen.log.info command + ' setup was successful'
        when 'F'
          Origen.log.error command + ' setup FAILED with the following message:'
          Origen.log.error response.chomp
        else
          Origen.log.error 'Non standard response from ' + command + ' setup: ' + response
        end
      else
        # response was nil.  The server died
        Origen.log.error command + ' caused a nil response.  The server likely died.'
      end
    end
  end
end

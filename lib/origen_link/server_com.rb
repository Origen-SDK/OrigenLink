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
      t1 = 0
      t2 = 0
      t3 = 0
      t4 = 0
      t5 = 0
      response = ''
      user_status = ''
      success = false

      until success
        t1 = Time.now

        # open a connection to the server, send the command and wait for a response
        TCPSocket.open(@address, @port) do |link|
          t2 = Time.now
          link.write(@user_name + "\n" + cmdstr + ':' + argstr + "\n\n")
          t3 = Time.now
          user_status = link.gets
          response = link.gets
          t4 = Time.now
        end

        t5 = Time.now

        if @initial_comm_sent && ((user_status =~ /user_change/) || (response =~ /Busy:/))
          # there has been a collision
          Origen.log.error 'A collision (another user interrupted your link session) has occured'
          Origen.log.error "When using debug mode ensure that you don't exceed the 20 minute communication time out"
          exit
        end

        if response =~ /Busy:/
          Origen.log.error response + ' retry in 1 second'
          sleep(1)
        else
          success = true
          @initial_comm_sent = true
        end
      end

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
      @pattern_link_messages << "#{cmdstr}:#{argstr}"
      response    # ensure the response is passed along
    end

    def send_batch(vector_batch)
      vector_batch_str = @user_name + "\n" + vector_batch.join("\n") + "\n\n"
      user_status = ''
      success = false

      until success
        t1 = 0
        t2 = 0
        t3 = 0
        t4 = 0
        t5 = 0
        response = []
        t1 = Time.now
        TCPSocket.open(@address, @port) do |link|
          t2 = Time.now
          link.write(vector_batch_str)
          t3 =  Time.now
          while line = link.gets
            response << line.chomp
          end
          t4 = Time.now
        end
        t5 = Time.now

        user_status = response.delete_at(0)
        if @initial_comm_sent && ((user_status =~ /user_change/) || (response[0] =~ /Busy:/))
          # there has been a collision
          Origen.log.error 'A collision (another user interrupted your link session) has occured'
          Origen.log.error "When using debug mode ensure that you don't exceed the 20 minute communication time out"
          exit
        end

        if response[0] =~ /Busy:/
          Origen.log.error response[0] + ' retry in 1 second'
          sleep(1)
        else
          success = true
          @initial_comm_sent = true
        end

      end

      @total_comm_time += (t5 - t1)
      @total_connect_time += (t2 - t1)
      @total_xmit_time += (t3 - t2)
      @total_recv_time += (t4 - t3)
      @max_receive_time = (t4 - t3) if @max_receive_time < (t4 - t3)
      @total_packets += 1
      @pattern_link_messages.concat(vector_batch)
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
          Origen.log.debug command + ' setup was successful'
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

module OrigenLink
  module ConfigurationCommands
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
      # store pins to the pinmap hash, this is used to remove non-link pins
      # from the pattern in cases where the app includes too many pins
      pinmap_arr = @pinmap.split(',')
      0.step(pinmap_arr.size - 1, 2) { |p| @pinmap_hash[pinmap_arr[p]] = true }
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
      cmd = []
      cmd << 'pin_patternorder'
      cmd << pinorder.gsub(/\s+/, '')
      @pinorder = cmd[1]
      if @pinmap.nil?
        @batched_setup_cmds << cmd
      else
        response = send_cmd(cmd[0], @pinorder)
        setup_cmd_response_logger(cmd[0], response)
      end
    end

    # set_pinorder
    #   This method is called if the app has not explicitly set the pin order
    #   for the Link server using pinorder= (above)
    #
    #   Origen.app.pin_pattern_order is read to get the pin pattern order
    #   and pass it to pinorder=
    def set_pinorder
      pinlist = ''
      ordered_pins_cache.each do |pin|
        unless pin.is_a?(Hash)
          if pin.size == 1
            pinlist = pinlist + ',' unless pinlist.length == 0
            pinlist = pinlist + pin.name.to_s
          else
            dut.pins(pin.id).map.each do |sub_pin|
              pinlist = pinlist + ',' unless pinlist.length == 0
              pinlist = pinlist + sub_pin.name.to_s
            end
          end
        end
      end
      self.pinorder = pinlist
    end

    # pinformat=
    #   This method is used to setup the pin clock format on the debugger device.
    #   The supported formats are rl and rh
    #
    #   example:
    #     tester.pinformat = 'func_25mhz,tclk,rl'
    def pinformat=(pinformat)
      cmd = []
      cmd << 'pin_format'
      cmd << replace_tset_name_w_number(pinformat.gsub(/\s+/, ''))
      @pinformat = cmd[1]
      if @pinmap.nil?
        @batched_setup_cmds << cmd
      else
        response = send_cmd(cmd[0], @pinformat)
        setup_cmd_response_logger(cmd[0], response)
      end
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
      cmd = []
      cmd << 'pin_timing'
      cmd << replace_tset_name_w_number(pintiming.gsub(/\s+/, ''))
      @pintiming = cmd[1]
      if @pinmap.nil?
        @batched_setup_cmds << cmd
      else
        response = send_cmd(cmd[0], @pintiming)
        setup_cmd_response_logger(cmd[0], response)
      end
    end

    # process_timeset(tset)
    #   This method will check the pin timing api for the current timeset.
    #   If the timset is programmed, it will be processed into the Link
    #   timing format, registered, and sent to the server.
    #   Else, a warning message will be displayed
    #
    #   example generated command:
    #     send_cmd('pin_timingv2', '2,drive,5,data,tck;10,data,tdi|compare,35,data,tck,tdo;5,data,tdi')
    def process_timeset(tset)
      # Check to see if this timeset has been programmed
      if dut.timesets(tset.to_sym).nil?
        # Timset has not been programmed through the pin timing api
        tset_warning(tset)
        ''	# return empty string on failure
      else
        # Timeset has been programmed
        # accumulate and sort drive events
        drive_str = tset_argstr_from_events(dut.timesets(tset.to_sym).drive_waves)

        # accumulate and sort compare events
        compare_str = tset_argstr_from_events(dut.timesets(tset.to_sym).compare_waves)

        # construct the command argument string
        argstr = get_tset_number(tset).to_s
        if drive_str.length > 0
          argstr = argstr + ',drive,' + drive_str
          argstr = argstr + '|compare,' + compare_str if compare_str.length > 0
        elsif compare_str.length > 0
          argstr = argstr + ',compare,' + compare_str
        else
          fail "#{tset} timeset is programmed with no drive or compare edges"
        end

        # send the timeset information to the server
        cmd = []
        cmd << 'pin_timingv2'
        cmd << argstr
        if @pinmap.nil?
          @batched_setup_cmds << cmd
        else
          response = send_cmd('pin_timingv2', argstr)
          setup_cmd_response_logger('pin_timingv2', response)
        end

        # return the tset number from the tset hash
        "tset#{@tsets_programmed[tset]},"
      end
    end

    # tset_argstr_from_events(timing_waves)
    #   consume timing wave info and return command argstr format
    #   output: 10,data,tdi,tms;15,data,tck;25,0,tck;35,data,tms
    def tset_argstr_from_events(waves)
      event_time = []
      event_setting = {}
      event_pins = {}
      waves.each do |w|
        # skip any events wave that does not have any associated pins
        unless w.pins.size == 0
          w.evaluated_events.each do |e|
            event_key = e[0].to_f		# time stamp for the event
            event_time << event_key
            event_setting[event_key] = [] unless event_setting.key?(event_key)
            event_setting[event_key] << e[1].to_s

            event_pins[event_key] = [] unless event_pins.key?(event_key)
            event_pins[event_key] << []
            w.pins.each do |p|
              event_pins[event_key].last << p.id.to_s if @pinmap_hash[p.id.to_s]
            end
          end
        end
      end
      # now sort the events into time order and build the tset argstr
      event_time.uniq!
      event_time.sort!
      rtnstr = ''
      event_time.each do |event_key|
        rtnstr = rtnstr + ';' unless rtnstr.length == 0
        event_setting[event_key].each_index do |i|
          pins = event_pins[event_key][i].uniq.join(',')
          rtnstr = rtnstr + ';' if i > 0
          rtnstr = rtnstr + event_key.to_s + ',' + event_setting[event_key][i] + ',' + pins if pins.length > 0
        end
      end
      rtnstr.gsub(/;+/, ';')
    end

    # tset_warning(tset)
    #   This method is used to display a no timing info warning.
    #   The warning is displayed only once per tset that is
    #   encountered
    def tset_warning(tset)
      unless @tsets_warned.key?(tset)
        Origen.log.warn("No timing information provided for timeset :#{tset}")
        Origen.log.warn('Default timing will be used (pin operations are in pattern order)')
        Origen.log.warn('Specify timing through the timing api or by using:')
        Origen.log.warn("  tester.pinformat = 'func_25mhz,tclk,rl'")
        Origen.log.warn("  tester.pintiming = 'func_25mhz,tms,0,tdi,0,tdo,1'")
        @tsets_warned[tset] = true
      end
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
  end
end

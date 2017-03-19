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

    # set_pinorder
    #   This method is called if the app has not explicitly set the pin order
    #   for the Link server using pinorder= (above)
    #
    #   Origen.app.pin_pattern_order is read to get the pin pattern order
    #   and pass it to pinorder=
    def set_pinorder
      pinlist = ''
      Origen.app.pin_pattern_order.each do |pin|
        pinlist = pinlist + ',' unless pinlist.length == 0
        pinlist = pinlist + pin.to_s unless pin.is_a?(Hash)
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
  end
end

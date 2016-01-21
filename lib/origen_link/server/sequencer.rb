require 'origen_link/server/pin'

##################################################
# OrigenLink::Server::Sequencer Class
#    Instance variables:
#      pinmap: hash with ["pin name"] = pin object
#      patternpinindex: hash with ["pin name"] =
#        integer index into vector data
#      patternpinorder: Array with pin names in
#        the vector order
#
#    This class processes messages targeted for
#    pin sequencer interface (vector pattern
#    execution).
#
#    Supported messages:
#      pin_assign (create pin mapping)
#        ex: "pin_assign:tck,3,extal,23,tdo,5"
#
#      pin_patternorder (define vector pin order)
#        ex: "pin_patternorder:tdo,extal,tck"
#
#      pin_cycle (execute vector data)
#        ex: "pin_cycle:H11"
#
#      pin_clear (clear all setup information)
#        ex: "pin_clear:"
#
#      pin_format (setup a pin with return format)
#        first argument is the timeset
#        ex: "pin_format:1,tck,rl"
#
#      pin_timing (define when pin events happen)
#        timing is stored in a timeset hash
#        first argument is the timeset key
#        ex: "pin_timing:1,tdi,0,tdo,1,tms,0
#
#      version (check version of app server is
#        running)
#        ex: "version:"
#        response ex: "P:0.2.0.pre0"
##################################################
module OrigenLink
  module Server
    def self.gpio_dir=(path)
      @gpio_dir = path
    end

    def self.gpio_dir
      @gpio_dir || '/sys/class/gpio'
    end

    class Sequencer
      attr_accessor :version
      attr_reader :pinmap
      attr_reader :patternorder
      attr_reader :cycletiming
      attr_reader :patternpinindex

      ##################################################
      # initialize method
      #    Create empty pinmap, pattern pin index
      #    and pattern order instance variables
      ##################################################
      def initialize
        @pinmap = Hash.new(-1)
        @patternpinindex = Hash.new(-1)
        @patternorder = []
        @cycletiming = Hash.new(-1)
        @version = ''
      end

      ##################################################
      # processmessage method
      #    arguments: message
      #      message format is <group>_<command>:<args>
      #    returns: message response
      #
      #    This method splits a message into it's
      #    command and arguments and passes this
      #    information to the method that performs
      #    the requested command
      ##################################################
      def processmessage(message)
        command = message.split(':')

        case command[0]
        when 'pin_assign'
          pin_assign(command[1])
        when 'pin_patternorder'
          pin_patternorder(command[1])
        when 'pin_cycle'
          pin_cycle(command[1])
        when 'pin_clear'
          pin_clear
        when 'pin_format'
          pin_format(command[1])
        when 'pin_timing'
          pin_timing(command[1])
        when 'pin_timingv2'
          pin_timingv2(command[1])
        when 'version'
          "P:#{@version}"
        else
          'Error Invalid command: ' + command[0].to_s
        end
      end

      ##################################################
      # pin_assign method
      #    arguments: <args> from the message request
      #      see "processmessage" method
      #    returns: "P:" or error message
      #
      #    This method creates a pin instance for each
      #    pin in the pin map and builds the pinmap
      #    hash.  Before the pinmap is created, any
      #    information from a previous pattern run is
      #    cleared.
      ##################################################
      def pin_assign(args)
        pin_clear
        success = true
        fail_message = ''
        argarr = args.split(',')
        0.step(argarr.length - 2, 2) do |index|
          @pinmap[argarr[index]] = Pin.new(argarr[index + 1])
          unless @pinmap[argarr[index]].gpio_valid
            success = false
            fail_message = fail_message + 'pin ' + argarr[index] + ' gpio' + argarr[index + 1] + ' is invalid'
          end
        end
        if success
          'P:'
        else
          'F:' + fail_message
        end
      end

      ########################################################
      # pin_timingv2 method
      #   arguments: <args> from the message request
      #     Should be '1,drive,5,pin,10,pin2,|compare,0,pin3'
      #     First integer is timeset number
      #
      #   returns "P:" or error message
      #
      #   This method sets up a time set.  Any arbitrary
      #   waveform can be generated
      #
      ########################################################
      def pin_timingv2(args)
        # get the tset number
        argarr = args.split(',')
        tset_key = argarr.delete_at(0).to_i
        new_timeset(tset_key)
        args = argarr.join(',')

        # process and load the timeset
        waves = args.split('|')
        waves.each do |w|
          argarr = w.split(',')
          wave_type = argarr.delete_at(0)
          event_data_key = wave_type + '_event_data'
          event_pins_key = wave_type + '_event_pins'
          w = argarr.join(',')
          events = w.split(';')
          events.each do |e|
            argarr = e.split(',')
            event_key = argarr.delete_at(0)
            @cycletiming[tset_key]['events'] << event_key
            @cycletiming[tset_key][event_data_key][event_key] = argarr.delete_at(0)
            # now load the pins for this event
            @cycletiming[tset_key][event_pins_key][event_key] = []
            argarr.each do |pin|
              @cycletiming[tset_key][event_pins_key][event_key] << @pinmap[pin]
            end # of argarr.each
          end # of events.each
        end # of waves.each
        @cycletiming[tset_key]['events'].uniq!
        @cycletiming[tset_key]['events'].sort!
        'P:'
      end # of def pin_timingv2

      ##################################################
      # new_timeset(tset)
      #   creates a new empty timeset hash
      #
      #   timing format:
      #     ['events'] = [0, 5, 10, 35]
      #     ['drive_event_data'] = {
      #           0: 'data'
      #          10: 'data'
      #          35: '0'
      #         }
      #     ['drive_event_pins'] = {
      #           0: [pin_obj1, pin_obj2]
      #           etc.
      #         }
      ##################################################
      def new_timeset(tset)
        @cycletiming[tset] = {}
        @cycletiming[tset]['events'] = []
        @cycletiming[tset]['drive_event_data'] = {}
        @cycletiming[tset]['drive_event_pins'] = {}
        @cycletiming[tset]['compare_event_data'] = {}
        @cycletiming[tset]['compare_event_pins'] = {}
      end

      ##################################################
      # pin_format method
      #   arguments: <args> from the message request
      #     Should be <timeset>,<pin>,rl or rh
      #     multi-clock not currently supported
      #
      ##################################################
      def pin_format(args)
        argarr = args.split(',')
        tset_key = argarr.delete_at(0).to_i
        new_timeset(tset_key) unless @cycletiming.key?(tset_key)
        @cycletiming[tset_key]['events'] += [1, 3]
        @cycletiming[tset_key]['events'].sort!
        [1, 3].each do |event|
          @cycletiming[tset_key]['drive_event_pins'][event] = []
        end
        @cycletiming[tset_key]['compare_event_data'][1] = 'data'
        0.step(argarr.length - 2, 2) do |index|
          drive_type = argarr[index + 1]
          pin_name = argarr[index]
          @cycletiming[tset_key]['drive_event_data'][1] = 'data'
          @cycletiming[tset_key]['drive_event_pins'][1] << @pinmap[pin_name]
          @cycletiming[tset_key]['drive_event_pins'][3] << @pinmap[pin_name]
          @cycletiming[tset_key]['compare_event_pins'][1] = [@pinmap[pin_name]]
          if drive_type == 'rl'
            @cycletiming[tset_key]['drive_event_data'][3] = '0'
          else
            @cycletiming[tset_key]['drive_event_data'][3] = '1'
          end
        end
        'P:'
      end

      ##################################################
      # pin_timing method
      #   arguments: <args> from the message request
      #     Should be '1,pin,-1,pin2,0,pin3,1'
      #     First integer is timeset number
      #     If argument is '', default timing is created
      #     Default timeset number is 0, this is used
      #     if no timeset is explicitly defined
      #
      #     cycle arg:  0   1   2
      #     waveform : ___/***\___
      #
      #   returns "P:" or error message
      #
      #   This method sets up a time set.  All retrun
      #   format pins are driven between 0 and 1 and
      #   return between 1 and 2.  Non-return pins are
      #   acted upon during the 0, 1 or 2 time period.
      #
      ##################################################
      def pin_timing(args)
        argarr = args.split(',')
        tset_key = argarr.delete_at(0).to_i
        new_timeset(tset_key) unless @cycletiming.key?(tset_key)
        [0, 2, 4].each do |event|
          @cycletiming[tset_key]['drive_event_pins'][event] = []
          @cycletiming[tset_key]['compare_event_pins'][event] = []
        end

        # process the information received
        0.step(argarr.length - 2, 2) do |index|
          event = argarr[index + 1].to_i
          # reorder event number to allow rising/falling edges
          event *= 2
          pin_name = argarr[index]
          @cycletiming[tset_key]['events'] << event
          @cycletiming[tset_key]['drive_event_data'][event] = 'data'
          @cycletiming[tset_key]['drive_event_pins'][event] << @pinmap[pin_name]
          @cycletiming[tset_key]['compare_event_data'][event] = 'data'
          @cycletiming[tset_key]['compare_event_pins'][event] << @pinmap[pin_name]
        end

        # remove events with no associated pins
        @cycletiming[tset_key]['events'].uniq!
        @cycletiming[tset_key]['events'].sort!
        [0, 2, 4].each do |event|
          if @cycletiming[tset_key]['drive_event_pins'][event].size == 0
            @cycletiming[tset_key]['events'] -= [event]
            @cycletiming[tset_key]['drive_event_data'].delete(event)
            @cycletiming[tset_key]['drive_event_pins'].delete(event)
            @cycletiming[tset_key]['compare_event_data'].delete(event)
            @cycletiming[tset_key]['compare_event_pins'].delete(event)
          end
        end
        'P:'
      end

      ##################################################
      # pin_patternorder method
      #    arguments: <args> from the message request
      #    returns: "P:" or error message
      #
      #    This method is used to define the order
      #    for pin vector data.
      ##################################################
      def pin_patternorder(args)
        argarr = args.split(',')
        index = 0
        new_timeset(0)
        argarr.each do |pin|
          @patternorder << pin
          @pinmap[pin].pattern_index = index	# pattern index stored in pin object now
          @patternpinindex[pin] = index		# to be removed

          # define default timing
          @cycletiming[0]['events'] << index
          @cycletiming[0]['drive_event_data'][index] = 'data'
          @cycletiming[0]['drive_event_pins'][index] = [@pinmap[pin]]
          @cycletiming[0]['compare_event_data'][index] = 'data'
          @cycletiming[0]['compare_event_pins'][index] = [@pinmap[pin]]
          index += 1
        end
        'P:'
      end

      ##################################################
      # pin_cycle method
      #    arguments: <args> from the message request
      #    returns: "P:" or "F:" followed by results
      #
      #    This method executes one cycle of pin vector
      #    data.  The vector data is decomposed and
      #    sequenced.  Each pin object and pin data
      #    is passed to the "process_pindata" method
      #    for decoding and execution
      #
      ##################################################
      def pin_cycle(args)
        # set default repeats and timeset
        repeat_count = 1
        tset = 0
        if args =~ /,/
          parsedargs = args.split(',')
          args = parsedargs.pop
          parsedargs.each do |arg|
            if arg =~ /repeat/
              repeat_count = arg.sub(/repeat/, '').to_i
            elsif arg =~ /tset/
              tset = arg.sub(/tset/, '').to_i
            end
          end
        end

        message = ''
        # load pattern cycle data into pin objects
        @pinmap.each_value { |p| p.load_pattern_data(args) }
        cycle_failure = false

        0.upto(repeat_count - 1) do |count|
          # process timing events
          @cycletiming[tset]['events'].each do |event|
            # process drive events
            if @cycletiming[tset]['drive_event_pins'].key?(event)
              @cycletiming[tset]['drive_event_pins'][event].each do |p|
                p.process_event(:drive, @cycletiming[tset]['drive_event_data'][event])
              end
            end

            # process compare events
            if @cycletiming[tset]['compare_event_pins'].key?(event)
              @cycletiming[tset]['compare_event_pins'][event].each do |p|
                p.process_event(:compare, @cycletiming[tset]['compare_event_data'][event])
              end
            end
          end # event

          # build response message
          message += ' ' unless count == 0

          @patternorder.each do |p|
            message += @pinmap[p].response
            cycle_failure = true if @pinmap[p].cycle_failure
          end
        end # count
        if cycle_failure
          rtnmsg = 'F:' + message + '    Expected:' + args
        else
          rtnmsg = 'P:' + message
        end
        rtnmsg
      end

      ##################################################
      # pin_clear method
      #
      #    This method clears all storage objects.  It
      #    is called by the "pin_assign" method
      ##################################################
      def pin_clear
        @pinmap.each { |pin_name, pin| pin.destroy }
        @pinmap.clear
        @patternpinindex.clear
        @patternorder.delete_if { true }
        @cycletiming.clear
        'P:'
      end
    end
  end
end

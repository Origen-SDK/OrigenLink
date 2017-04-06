# OrigenLink::Server::Pin class manipulate input/output pins of the Udoo
# using exported file objects.  If the pin is not exported, it
# will be exported when a pin is initialized
#

module OrigenLink
  module Server
    # The server pin class is used to perform IO using the UDOO pins
    class Pin
      @@pin_setup = {
        in:  'in',
        out: 'out'
      }

      # True if this pin exists in /sys/class/gpio after export.  False otherwise.
      attr_reader :gpio_valid
      # This pin's vector data for the pattern cycle being executed
      attr_accessor :pattern_data
      # This pin's index in the vector data received from the plug-in app
      attr_accessor :pattern_index
      # This pin's response for the executing vector
      attr_accessor :response

      # Export the pin io files through the system and take control of the IO
      #
      # This method will execute system command
      # "echo #{ionumber} > /sys/class/gpio/export"
      # to create the IO file interface.  It will
      # set the direction, initial pin state and initialize
      # instance variables
      #
      # Receives
      #  ionumber - required, value indicating the pin number (BCM IO number,
      #             not the header pin number)
      #  direction - optional, specifies the pin direction.  A pin is
      #              initialized as an input if a direction isn't specified.
      #
      def initialize(ionumber, direction = :in)
        @ionumber = Integer(ionumber)
        @pin_dir_name = "#{Server.gpio_dir}/gpio#{@ionumber}/direction"
        @pin_val_name = "#{Server.gpio_dir}/gpio#{@ionumber}/value"
        if !File.exist?(@pin_dir_name)
          system("echo #{@ionumber} > #{Server.gpio_dir}/export")
          sleep 0.05
          if $CHILD_STATUS == 0
            @gpio_valid = true
          else
            @gpio_valid = false
          end
        else
          @gpio_valid = true
        end
        if @gpio_valid
          if File.writable?(@pin_dir_name)
            @pin_dir_obj = File.open(@pin_dir_name, 'w')
            update_direction(direction)
          else
            @gpio_valid = false
            puts "#{@pin_dir_name} is not writable. Fix permissions or run as super user."
          end
          @pin_val_obj = File.open(@pin_val_name, 'r+') if @gpio_valid
        end
        @pattern_data = ''
        @pattern_index = -1
        @response = 'W'
        @cycle_failure = false
        @data_is_drive = false
      end

      # data_is_drive?
      #   returns whether the current pattern data is drive
      def data_is_drive?
        @data_is_drive
      end

      # data_is_compare?
      #   returns whether the current pattern data is compare
      def data_is_compare?
        !@data_is_drive
      end

      # cycle_failure
      #   returns a boolean indicating pass/fail status of this pin
      def cycle_failure
        if @response == 'W'
          true		# force failure if no operation performed
        else
          @cycle_failure
        end
      end

      # load_pattern_data
      #   Grab this pin's data character from the pattern data
      def load_pattern_data(cycle)
        if @pattern_index > -1
          @pattern_data = cycle[@pattern_index]
          @response = 'W'
          @cycle_failure = false
          if @pattern_data == '1' || @pattern_data == '0'
            @data_is_drive = true
          else
            @data_is_drive = false
          end
        else
          @gpio_valid = false
        end
      end

      # process_event(event)
      #   perform the requested pin operation and update the response (if required)
      def process_event(operation, requested_action)
        if operation == :drive
          if data_is_drive?
            if requested_action == 'data'
              out(@pattern_data)
              @response = @pattern_data
            else
              out(requested_action)
            end # requested_action == 'data'
          end # data_is_drive?
        end # operation == :drive
        if operation == :compare
          if data_is_compare?
            if requested_action == 'data'
              case self.in
                when '0'
                  @cycle_failure = true if @pattern_data == 'H'
                  if @pattern_data == 'X'
                    @response = '.'
                  else
                    @response = 'L'
                  end
                # end of when '0'
                when '1'
                  @cycle_failure = true if @pattern_data == 'L'
                  if @pattern_data == 'X'
                    @response = '`'
                  else
                    @response = 'H'
                  end
                # end of when '1'
                else
                  @response = 'W'
              end # case
            end # requested_action == 'data'
          end # data_is_compare?
        end # operation == :compare
      end

      # Close the file IO objects associated with this pin
      def destroy
        if @gpio_valid
          @pin_dir_obj.close
          @pin_val_obj.close
          # system("echo #{@ionumber} > /sys/class/gpio/unexport")
          # puts "pin #{@ionumber} is no longer exported"
        end
      end

      # Sets the output state of the pin.
      #
      # If the pin is setup as an input,
      # the direction will first be changed to output.
      #
      def out(value)
        if @gpio_valid
          if @direction == :in
            update_direction(:out)
          end
          @pin_val_obj.write(value)
          @pin_val_obj.flush
        end
      end

      # Reads and returns state of the pin.
      #
      # If the pin is setup as an output, the direction will first
      # be changed to input.
      #
      def in
        if @gpio_valid
          if @direction == :out
            update_direction(:in)
          end
          # below is original read - slow to reopen every time
          # File.open(@pin_val_name, 'r') do |file|
          #  file.read#.chomp
          # end
          # end original read
          @pin_val_obj.pos = 0
          @pin_val_obj.getc
        end
      end

      # Sets the pin direction
      #
      # Receives:
      #  direction - specifies the pin direction.  Input is default.
      #
      #  Valid direction values:
      #    :in	-	input
      #    :out	-	output
      def update_direction(direction)
        if @gpio_valid
          @pin_dir_obj.pos = 0
          @pin_dir_obj.write(@@pin_setup[direction])
          @pin_dir_obj.flush
          @direction = direction
        end
      end

      # Returns 'OrigenLinPin' + io number
      def to_s
        'OrigenLinkPin' + @ionumber.to_s
      end
    end
  end
end

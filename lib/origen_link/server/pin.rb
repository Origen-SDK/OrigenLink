# OrigenLink::Server::Pin class manipulate input/output pins of the Udoo
# using exported file objects.  If the pin is not exported, it
# will be exported when a pin is initialized
#
# initialize:
#  description - This method will execute system command
#                "sudo echo ionumber > /sys/class/gpio/export"
#                to create the IO file interface.  It will
#                set the direction, initial pin state and initialize
#                instance variables
#  ionumber - required, value indicating the pin number (BCM IO number,
#             not the header pin number)
#  direction - optional, specifies the pin direction.  A pin is
#              initialized as an input if a direction isn't specified.
#
#
#  out:
#    description - Sets the output state of the pin.  If the pin
#                  is setup as an input, the direction will first
#                  be changed to output.
#
#
#  in:
#    description - Reads and returns state of the pin.  If the pin
#                  is setup as an output, the direction will first
#                  be changed to input.
#
#
#  update_direction:
#    description - Sets the pin direction
#
#  direction - specifies the pin direction.  A pin is
#              initialized as an input if a direction isn't specified.
#
#  Valid direction values:
#    :in	-	input
#    :out	-	output
#    :out_high	-	output, initialized high
#    :out_low	-	output, initialized low
module OrigenLink
  module Server
    class Pin
      @@pin_setup = {
        in:       'in',
        out:      'out',
        out_high: 'high',
        out_low:  'low'
      }

      attr_reader :gpio_valid

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
      end

      def destroy
        if @gpio_valid
          @pin_dir_obj.close
          @pin_val_obj.close
          system("echo #{@ionumber} > /sys/class/gpio/unexport")
          puts "pin #{@ionumber} is no longer exported"
        end
      end

      def out(value)
        if @gpio_valid
          if @direction == :in
            if value == 1
              update_direction(:out_high)
            else
              update_direction(:out_low)
            end
          end
          @pin_val_obj.write(value)
          @pin_val_obj.flush
        end
      end

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

      def update_direction(direction)
        if @gpio_valid
          @pin_dir_obj.pos = 0
          @pin_dir_obj.write(@@pin_setup[direction])
          @pin_dir_obj.flush
          if direction == :in
            @direction = direction
          else
            @direction = :out
          end
        end
      end

      def to_s
        'OrigenLinkPin' + @ionumber.to_s
      end
    end
  end
end

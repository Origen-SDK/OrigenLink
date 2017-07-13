require 'origen_link/server/pin'

module OrigenLink
  module Server
    class Jtag
      attr_reader :tdoval
      attr_accessor :verbose_enable
      attr_accessor :anytdofail

      def initialize(tdiio = 116, tdoio = 124, tmsio = 6, tckio = 119)
        @tdipin = Pin.new(tdiio, :out)
        @tdopin = Pin.new(tdoio, :in)
        @tmspin = Pin.new(tmsio, :out)
        @tckpin = Pin.new(tckio, :out)
        @tdoval = 0
        @tdostr = ''
        @verbose_enable = true
        @anytdofail = false
        @pins = {}
      end

      def destroy
        @tdipin.destroy
        @tdopin.destroy
        @tmspin.destroy
        @tckpin.destroy
        @tdipin = nil
        @tdopin = nil
        @tmspin = nil
        @tckpin = nil
        @pins.each_value(&:destroy)
      end

      def do_cycle(tdival, tmsval, capturetdo = false)
        @tdipin.out(tdival)
        @tmspin.out(tmsval)

        @tckpin.out(1)

        if capturetdo
          @tdostr = @tdopin.in + @tdostr
        end
        @tckpin.out(0)
      end

      def do_tlr
        8.times { do_cycle(0, 1) }
        do_cycle(0, 0)
      end

      def do_shift(numbits, value, capturetdo = false, suppresscomments = false, tdocompare = '')
        @tdoval = 0
        @tdostr = ''
        (numbits - 1).times do |bit|
          do_cycle(value[bit], 0, capturetdo)
        end
        do_cycle(value[numbits - 1], 1, capturetdo)

        @tdoval = @tdostr.to_i(2) if capturetdo

        if !(suppresscomments) && @verbose_enable && capturetdo
          puts 'TDO output = 0x' + @tdoval.to_s(16)
        end

        if capturetdo && tdocompare != ''
          thiscomparefail = false
          numbits.times do |bit|
            if tdocompare[numbits - 1 - bit] == 'H'
              compareval = 1
            elsif tdocompare[numbits - 1 - bit] == 'L'
              compareval = 0
            else
              compareval = @tdoval[bit]
            end

            if @tdoval[bit] != compareval
              @anytdofail = true
              thiscomparefail = true
            end
          end

          tdovalstr = @tdoval.to_s(2)
          tdovalstr = '0' * (numbits - tdovalstr.length) + tdovalstr
        end
      end

      def do_ir(numbits, value, options = {})
        defaults = {
          capturetdo:	      false,
          suppresscomments:	false,
          tdocompare:	      ''
        }
        options = defaults.merge(options)

        if options[:tdocompare] != ''
          capturetdo = true
        else
          capturetdo = options[:capturetdo]
        end

        # Assume starting from run test idle
        # Advance to shift IR
        do_cycle(0, 1)
        do_cycle(0, 1)
        do_cycle(0, 0)
        do_cycle(0, 0)

        do_shift(numbits, value, capturetdo, options[:suppresscomments], options[:tdocompare])

        # Return to run test idle
        do_cycle(0, 1)
        do_cycle(0, 0)
      end

      def do_dr(numbits, value, options = {})
        defaults = {
          capturetdo:	      true,
          suppresscomments:	false,
          tdocompare:	      ''
        }
        options = defaults.merge(options)

        if options[:tdocompare] != ''
          capturetdo = true
        else
          capturetdo = options[:tdocompare]
        end

        # Assume starting from run test idle
        # Advance to shift DR
        do_cycle(0, 1)
        do_cycle(0, 0)
        do_cycle(0, 0)

        do_shift(numbits, value, capturetdo, options[:suppresscomments], options[:tdocompare])

        # Return to run test idle
        do_cycle(0, 1)
        do_cycle(0, 0)
      end

      def pause_dr
        do_cycle(0, 1)
        do_cycle(0, 0)
        do_cycle(0, 0)
        do_cycle(0, 1)
        do_cycle(0, 0)
        do_cycle(0, 1)
        do_cycle(0, 1)
        do_cycle(0, 0)
      end

      def pause_ir
        do_cycle(0, 1)
        pause_dr
      end

      def read_adc(csl)
        channel_list = csl.split(',')
        response = ''
        channel_list.each do |channel|
          file_name = '/sys/bus/iio/devices/'
          case channel
            when 'A0'
              file_name = file_name + 'iio:device0/in_voltage0_raw'
            when 'A1'
              file_name = file_name + 'iio:device0/in_voltage1_raw'
            when 'A2'
              file_name = file_name + 'iio:device0/in_voltage2_raw'
            when 'A3'
              file_name = file_name + 'iio:device0/in_voltage3_raw'
            when 'A4'
              file_name = file_name + 'iio:device1/in_voltage0_raw'
            when 'A5'
              file_name = file_name + 'iio:device1/in_voltage1_raw'
          end
          response = response + ',' unless response.size == 0
          if File.exist?(file_name)
            File.open(file_name, 'r') do |file|
              reading = file.gets
              response = response + reading.strip
            end
          else
            response = response + '-1'
          end
        end
        response
      end

      def processmessage(message)
        message.strip!
        split_message = message.split(':')
        response = ''
        case split_message[0]
          when 'jtag_ir'
            args = split_message[1].split(',')
            do_ir(args[2].to_i, string_to_val(args[0], args[1]), capturetdo: true, suppresscomments: true)
            response = @tdoval.to_s(16)
          when 'jtag_dr'
            args = split_message[1].split(',')
            do_dr(args[2].to_i, string_to_val(args[0], args[1]), capturetdo: true, suppresscomments: true)
            response = @tdoval.to_s(16)
          when 'jtag_pause_dr'
            pause_dr
            response = 'done'
          when 'jtag_pause_ir'
            pause_ir
            response = 'done'
          when 'jtag_reset'
            do_tlr
            response = 'done'
          when 'jtag_pin_set'
            pinlist = split_message[1].split(',')
            pinlist.each do |pin|
              @pins[pin] = Pin.new(pin, :out) unless @pins.key?(pin)
              @pins[pin].out(1)
            end
            response = 'done'
          when 'jtag_pin_clear'
            pinlist = split_message[1].split(',')
            pinlist.each do |pin|
              @pins[pin] = Pin.new(pin, :out) unless @pins.key?(pin)
              @pins[pin].out(0)
            end
            response = 'done'
          when 'jtag_pin_read'
            pinlist = split_message[1].split(',')
            pinlist.each do |pin|
              @pins[pin] = Pin.new(pin, :in) unless @pins.key?(pin)
              response = response + @pins[pin].in
            end
            response
          when 'jtag_adc_read'
            response = read_adc(split_message[1])
            response
        end
      end

      def string_to_val(base_indicator, numstr)
        case base_indicator
          when 'h'
            numstr.to_i(16)
          when 'd'
            numstr.to_i(10)
          when 'b'
            numstr.to_i(2)
        end
      end
    end
  end
end

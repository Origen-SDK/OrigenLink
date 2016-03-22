# rubocop:disable Style/For: Prefer each over for.
require_relative 'pin_interface'

class OrigenLinkJtag
  attr_reader :tdoval
  attr_accessor :verbose_enable
  attr_accessor :anytdofail

  def initialize(tdiio = 16, tdoio = 23, tmsio = 19, tckio = 26, tck_period = 0.000001)
    @tdipin = OrigenLinkPin.new(tdiio, :out_low)
    @tdopin = OrigenLinkPin.new(tdoio, :in)
    @tmspin = OrigenLinkPin.new(tmsio, :out_low)
    @tckpin = OrigenLinkPin.new(tckio, :out_low)
    @tck_half_period = tck_period / 2
    @tdoval = 0
    @tdostr = ''
    @verbose_enable = true
    @anytdofail = false
  end

  def tck_period=(value)
    @tck_half_period = value / 2
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
  end

  def do_cycle(tdival, tmsval, capturetdo = false)
    @tdipin.out(tdival)
    @tmspin.out(tmsval)
    sleep @tck_half_period
    @tckpin.out(1)
    sleep @tck_half_period

    if capturetdo
      @tdostr = @tdopin.in + @tdostr
    end
    @tckpin.out(0)
  end

  def do_tlr
    for step in 1..8 do do_cycle(0, 1) end
    do_cycle(0, 0)
  end

  def do_shift(numbits, value, capturetdo = false, suppresscomments = false, tdocompare = '')
    @tdoval = 0
    @tdostr = ''
    for bit in 0..numbits - 2 do
      do_cycle(value[bit], 0, capturetdo)
    end
    do_cycle(value[numbits - 1], 1, capturetdo)

    @tdoval = @tdostr.to_i(2) if capturetdo

    if !(suppresscomments) && @verbose_enable && capturetdo
      puts 'TDO output = 0x' + @tdoval.to_s(16)
    end

    if capturetdo && tdocompare != ''
      thiscomparefail = false
      for bit in 0..numbits - 1 do
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

      if thiscomparefail
        puts '****************************>>>>>>>>>>>>>>>>> TDO failure <<<<<<<<<<<<<<<<<<****************************'
        puts 'expected: ' + tdocompare
        puts 'received: ' + tdovalstr
      else
        puts 'TDO compare pass'
        puts 'expected: ' + tdocompare
        puts 'received: ' + tdovalstr
      end
    end
  end

  def do_ir(numbits, value, options = {})
    defaults = {
      capturetdo:	      false,
      suppresscomments:	false,
      tdocompare:	      ''
    }
    options = defaults.merge(options)

    if !(options[:suppresscomments]) && @verbose_enable
      puts "	shift IR, #{numbits} bits, value = 0x" + value.to_s(16)
    end

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
    if !(options[:suppresscomments]) && @verbose_enable
      puts "	shift DR, #{numbits} bits, value = 0x" + value.to_s(16)
    end

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
end

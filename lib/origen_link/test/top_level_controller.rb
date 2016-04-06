module OrigenLink
  module Test
    class TopLevelController
      include Origen::Controller

      include OrigenJTAG

      JTAG_CONFIG = {
        tclk_format:	  :rl,
        # tclk_format:     :rh,
        tclk_multiple:	1,
        # tclk_multiple:   4,
        tdo_strobe:    :tclk_high,
        # tdo_store_cycle: 3,
        init_state:    :idle
      }

      def startup(options)
        pp 'Enter test mode' do
          # if tester.link?
          if tester.to_s == 'OrigenLink::VectorBased'
            # tester.initialize_pattern
            # below is for testing return format timing, requires tclk to be rl and multiple of 1
            tester.pinformat = 'func_25mhz,tclk,rl'
            tester.pintiming = 'func_25mhz,tdi,0,tms,0,tdo,1'
          end
          tester.set_timeset('func_25mhz', 40)   # Where 40 is the period in ns
          tester.wait time_in_us: 100
        end
      end

      def shutdown(options)
        pp 'Reset the device' do
          pin(:resetb).drive!(0)
          pin(:tclk).drive!(0)
        end
        # if tester.link?
        if tester.to_s == 'OrigenLink::VectorBased'
          # tester.finalize_pattern
        end
      end
    end
  end
end

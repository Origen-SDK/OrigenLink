module OrigenLink
  module CaptureSupport
    # Capture a vector
    #
    # This method applies a store vector request to the previous vector, note that is does
    # not actually generate a new vector.
    #
    # The captured data is added to the captured_data array.
    #
    # This method is indended to be used by pin drivers, see the #capture method for the application
    # level API.
    #
    # @example
    #   $tester.cycle                # This is the vector you want to capture
    #   $tester.store                # This applies the store request
    def store(*pins)
      options = pins.last.is_a?(Hash) ? pins.pop : {}
      fail 'The store is not implemented yet on Link'
    end

    # Capture the next vector generated
    #
    # This method applies a store request to the next vector to be generated,
    # note that is does not actually generate a new vector.
    #
    # The captured data is added to the captured_data array.
    #
    # This method is indended to be used by pin drivers, see the #capture method for the application
    # level API.
    #
    # @example
    #   tester.store_next_cycle
    #   tester.cycle                # This is the vector that will be captured
    def store_next_cycle(*pins)
      options = pins.last.is_a?(Hash) ? pins.pop : {}
      flush_vector
      @store_pins = pins
    end

    # Capture any store data within the given block, return it and then internally clear the tester's
    # capture memory.
    #
    # @example
    #
    #   v = tester.capture do
    #     my_reg.store!
    #   end
    #   v      # => Data value read from my_reg on the DUT
    def capture(*args)
      if block_given?
        yield
        synchronize
        d = @captured_data
        @captured_data = []
        d
      else
        # On other testers capture is an alias of store
        store(*args)
      end
    end

    private

    def capture_data(response)
      if @store_pins.size > 1
        fail 'Data capture on multiple pins is not implemented yet'
      else
        captured_data[0] ||= 0
        captured_data[0] = (captured_data[0] << 1) | extract_value(response, @store_pins[0])
        @store_pins = []
      end
    end

    def extract_value(response, pin)
      v = response[index_of(pin) + 2]
      if v == '`'
        1
      elsif v == '.'
        0
      else
        fail "Failed to extract value for pin #{pin.name}, character in response is: #{v}"
      end
    end

    # Returns the vector index (position) of the given pin
    def index_of(pin)
      i = @pinorder.split(',').index(pin.name.to_s)
      unless i
        fail "Data capture of pin #{pin.name} has been requested, but it has not been included in the Link pinmap!"
      end
      i
    end
  end
end

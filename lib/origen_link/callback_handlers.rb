module OrigenLink
  class CallbackHandlers
    include Origen::Callbacks

    def pattern_generated(output_file)
      tester.finalize_pattern
    end

    def before_pattern(pattern_name)
      tester.initialize_pattern
    end
  end
end

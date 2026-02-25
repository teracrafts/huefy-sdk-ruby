# frozen_string_literal: true

module Huefy
  module Http
    # Handles retry logic with exponential backoff and jitter for the
    # Huefy Ruby SDK.
    class RetryHandler
      # @param config [Hash] retry configuration
      # @option config [Integer] :max_retries maximum retry attempts (default: 3)
      # @option config [Float] :base_delay base delay in seconds (default: 1.0)
      # @option config [Float] :max_delay maximum delay in seconds (default: 30.0)
      # @option config [Array<Integer>] :retryable_status_codes HTTP codes eligible for retry
      def initialize(config = {})
        @max_retries = config[:max_retries] || 3
        @base_delay = config[:base_delay] || 1.0
        @max_delay = config[:max_delay] || 30.0
        @retryable_status_codes = config[:retryable_status_codes] || [429, 500, 502, 503, 504]
      end

      # Executes a block and retries it up to +max_retries+ times when a
      # retryable error is encountered.
      #
      # The delay between attempts uses exponential backoff with +/-25% jitter,
      # but honours +retry_after+ values carried on {HuefyError} instances.
      #
      # @yield the operation to execute
      # @return the result of a successful invocation
      # @raise the last error encountered after all retries are exhausted
      def execute(&block)
        last_error = nil

        (0..@max_retries).each do |attempt|
          begin
            return block.call
          rescue StandardError => e
            last_error = e

            # If all retries exhausted, break immediately.
            break if attempt >= @max_retries

            # Only retry when the error is eligible.
            break unless retryable?(e)

            # Determine delay -- prefer retry_after from the error when present.
            delay = if e.is_a?(HuefyError) && e.retry_after && e.retry_after > 0
                      [e.retry_after, @max_delay].min
                    else
                      calculate_delay(attempt)
                    end

            sleep(delay)
          end
        end

        raise last_error || HuefyError.new(
          "All retry attempts exhausted",
          code: ErrorCodes::NETWORK_RETRY_LIMIT
        )
      end

      # Returns true when the error is eligible for retry based on its HTTP
      # status code.
      #
      # @param error [StandardError] the error to check
      # @return [Boolean]
      def retryable?(error)
        return false unless error.is_a?(HuefyError)
        return false unless error.status_code

        @retryable_status_codes.include?(error.status_code)
      end

      # Calculates the delay for a given retry attempt using exponential
      # backoff with +/-25% jitter.
      #
      # @param attempt [Integer] zero-based attempt index (0 = first retry)
      # @return [Float] delay in seconds
      def calculate_delay(attempt)
        exponential = @base_delay * (2**attempt)
        capped = [exponential, @max_delay].min

        # Apply +/-25% jitter: factor in [0.75, 1.25)
        jitter_factor = 0.75 + rand * 0.5
        capped * jitter_factor
      end
    end
  end
end

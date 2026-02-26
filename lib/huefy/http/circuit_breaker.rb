# frozen_string_literal: true

module Huefy
  module Http
    # Thread-safe circuit breaker implementing the standard three-state
    # pattern (closed, open, half-open).
    #
    # - **CLOSED** -- requests flow normally. Consecutive failures increment a
    #   counter; once the threshold is reached the circuit opens.
    # - **OPEN** -- requests are rejected immediately with a circuit-open error
    #   until +reset_timeout+ has elapsed, at which point the circuit transitions
    #   to half-open.
    # - **HALF_OPEN** -- a limited number of probe requests are allowed through.
    #   Success closes the circuit; failure re-opens it.
    class CircuitBreaker
      # Possible circuit states.
      CLOSED    = :closed
      OPEN      = :open
      HALF_OPEN = :half_open

      # @return [Symbol] current circuit state
      attr_reader :state

      # @param failure_threshold [Integer] failures before the circuit opens (default: 5)
      # @param reset_timeout [Float] seconds the circuit stays open (default: 30.0)
      # @param half_open_requests [Integer] probe requests in half-open (default: 1)
      def initialize(failure_threshold: 5, reset_timeout: 30.0, half_open_requests: 1)
        @failure_threshold = failure_threshold
        @reset_timeout = reset_timeout
        @half_open_requests = half_open_requests

        @mutex = Mutex.new
        reset
      end

      # Wraps a block with circuit breaker semantics.
      #
      # The mutex is only held for state checks and counter mutations, never
      # during the actual block execution, so concurrent requests are not
      # serialised.
      #
      # @yield the operation to protect
      # @return the result of the block
      # @raise [HuefyError] with code CIRCUIT_OPEN when the circuit is open
      def execute(&block)
        @mutex.synchronize do
          check_state_and_admit
        end

        begin
          result = block.call
          @mutex.synchronize { record_success }
          result
        rescue StandardError => e
          if e.respond_to?(:recoverable?) && e.recoverable?
            @mutex.synchronize { record_failure }
          end
          raise
        end
      end

      # Returns the current circuit state, accounting for automatic
      # transition from open to half-open.
      #
      # @return [Symbol]
      def current_state
        @mutex.synchronize do
          check_open_to_half_open
          @state
        end
      end

      # Resets the circuit breaker to a pristine closed state.
      def reset
        @state = CLOSED
        @failures = 0
        @successes = 0
        @half_open_attempts = 0
        @last_failure_time = nil
        @last_success_time = nil
      end

      # Returns a snapshot of the circuit breaker statistics.
      #
      # @return [Hash]
      def stats
        @mutex.synchronize do
          {
            state: @state,
            failures: @failures,
            successes: @successes,
            last_failure: @last_failure_time,
            last_success: @last_success_time
          }
        end
      end

      private

      # Called inside @mutex. Raises if the circuit will not admit a request;
      # otherwise prepares state so the request can proceed.
      def check_state_and_admit
        case @state
        when OPEN
          if @last_failure_time.nil?
            transition_to(CLOSED)
            return
          end

          elapsed = Time.now - @last_failure_time

          if elapsed >= @reset_timeout
            transition_to(HALF_OPEN)
            @half_open_attempts = 0
          else
            retry_after = @reset_timeout - elapsed
            raise HuefyError.circuit_open_error(retry_after: retry_after)
          end

          # Now in HALF_OPEN — fall through to the half-open check below
          check_half_open_admission
        when HALF_OPEN
          check_half_open_admission
        end
        # CLOSED always admits
      end

      def check_half_open_admission
        if @half_open_attempts >= @half_open_requests
          raise HuefyError.circuit_open_error(retry_after: @reset_timeout)
        end

        @half_open_attempts += 1
      end

      # Called inside @mutex after a successful request.
      def record_success
        @successes += 1
        @last_success_time = Time.now

        case @state
        when HALF_OPEN
          transition_to(CLOSED)
        when CLOSED
          @failures = 0
        end
      end

      # Called inside @mutex after a failed request.
      def record_failure
        @failures += 1
        @last_failure_time = Time.now

        case @state
        when CLOSED
          transition_to(OPEN) if @failures >= @failure_threshold
        when HALF_OPEN
          transition_to(OPEN)
        end
      end

      def transition_to(new_state)
        @state = new_state
        if new_state == CLOSED
          @failures = 0
          @half_open_attempts = 0
        end
      end

      def check_open_to_half_open
        return unless @state == OPEN && @last_failure_time

        elapsed = Time.now - @last_failure_time
        if elapsed >= @reset_timeout
          transition_to(HALF_OPEN)
          @half_open_attempts = 0
        end
      end
    end
  end
end

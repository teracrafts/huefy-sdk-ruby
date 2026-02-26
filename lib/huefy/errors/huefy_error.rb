# frozen_string_literal: true

module Huefy
  # The primary error class raised by the Huefy Ruby SDK.
  #
  # Carries structured information about the error including its category,
  # recoverability, and optional details.
  class HuefyError < StandardError
    # @return [String] the categorized error code
    attr_reader :code

    # @return [Error, nil] the underlying cause error
    attr_reader :cause_error

    # @return [Integer, nil] HTTP status code, if applicable
    attr_reader :status_code

    # @return [Float, nil] suggested seconds to wait before retrying
    attr_reader :retry_after

    # @return [String, nil] request ID from the server
    attr_reader :request_id

    # @return [Time] when the error was created
    attr_reader :timestamp

    # @return [Hash] additional structured error details
    attr_reader :details

    # @param message [String] human-readable error message
    # @param code [String] error code from {ErrorCodes}
    # @param cause [Error, nil] underlying cause
    # @param status_code [Integer, nil] HTTP status code
    # @param retry_after [Float, nil] seconds to wait before retrying
    # @param request_id [String, nil] server request ID
    # @param details [Hash] additional details
    def initialize(
      message,
      code:,
      cause: nil,
      status_code: nil,
      retry_after: nil,
      request_id: nil,
      details: {}
    )
      super(message)
      @code = code
      @cause_error = cause
      @status_code = status_code
      @retry_after = retry_after
      @request_id = request_id
      @timestamp = Time.now
      @details = details
    end

    # @return [String] formatted error string
    def to_s
      if @cause_error
        "[#{@code}] #{message}: #{@cause_error.message}"
      else
        "[#{@code}] #{message}"
      end
    end

    # @return [Integer] the numeric code for this error
    def numeric_code
      ErrorCodes.numeric_code(@code)
    end

    # @return [Boolean] whether this error is recoverable
    def recoverable?
      ErrorCodes.recoverable?(@code)
    end

    # Returns a new error with additional details merged in.
    #
    # @param extra [Hash] additional details to merge
    # @return [HuefyError] new error with merged details
    def with_details(extra)
      self.class.new(
        message,
        code: @code,
        cause: @cause_error,
        status_code: @status_code,
        retry_after: @retry_after,
        request_id: @request_id,
        details: @details.merge(extra)
      )
    end

    # -- Factory methods -------------------------------------------------------

    # Creates a recoverable network error.
    def self.network_error(message, cause: nil)
      new(message, code: ErrorCodes::NETWORK_ERROR, cause: cause)
    end

    # Creates a timeout error.
    def self.timeout_error(message)
      new(message, code: ErrorCodes::NETWORK_TIMEOUT)
    end

    # Creates a non-recoverable authentication error.
    def self.authentication_error(message)
      new(message, code: ErrorCodes::AUTH_UNAUTHORIZED, status_code: 401)
    end

    # Creates a non-recoverable security error.
    def self.security_error(message)
      new(message, code: ErrorCodes::SECURITY_PII_DETECTED)
    end

    # Creates a missing API key error.
    def self.auth_missing_key(message)
      new(message, code: ErrorCodes::AUTH_MISSING_KEY)
    end

    # Creates a circuit-open error with a retry-after hint.
    def self.circuit_open_error(retry_after:)
      new(
        "Circuit breaker is open. Retry after #{retry_after.to_i}s.",
        code: ErrorCodes::CIRCUIT_OPEN,
        retry_after: retry_after
      )
    end

    # Creates an error from an HTTP response status code and body.
    #
    # @param status_code [Integer] HTTP status code
    # @param body [String, nil] response body
    # @param request_id [String, nil] value of the X-Request-Id response header
    # @param retry_after [Float, nil] parsed Retry-After value in seconds
    def self.from_response(status_code, body = nil, request_id: nil, retry_after: nil)
      case status_code
      when 401
        new(body || "Unauthorized", code: ErrorCodes::AUTH_UNAUTHORIZED, status_code: 401, request_id: request_id)
      when 403
        new(body || "Forbidden", code: ErrorCodes::AUTH_INVALID_KEY, status_code: 403, request_id: request_id)
      when 408
        new(body || "Request timeout", code: ErrorCodes::NETWORK_TIMEOUT, status_code: 408, request_id: request_id)
      when 429
        new(body || "Rate limited", code: ErrorCodes::NETWORK_RETRY_LIMIT, status_code: 429, request_id: request_id, retry_after: retry_after)
      when 500..599
        new(body || "Server error", code: ErrorCodes::NETWORK_SERVICE_UNAVAILABLE, status_code: status_code, request_id: request_id)
      else
        new(body || "HTTP #{status_code}", code: ErrorCodes::NETWORK_ERROR, status_code: status_code, request_id: request_id)
      end
    end
  end
end

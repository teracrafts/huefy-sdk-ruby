# frozen_string_literal: true

require "set"

module Huefy
  # Canonical error codes used throughout the Huefy Ruby SDK.
  #
  # Each constant carries a human-readable string value for serialization and
  # logging. A companion numeric code map is provided for systems that require
  # integer identifiers.
  module ErrorCodes
    # Initialization
    INIT_FAILED  = "INIT_FAILED"
    INIT_TIMEOUT = "INIT_TIMEOUT"

    # Authentication
    AUTH_INVALID_KEY  = "AUTH_INVALID_KEY"
    AUTH_EXPIRED_KEY  = "AUTH_EXPIRED_KEY"
    AUTH_MISSING_KEY  = "AUTH_MISSING_KEY"
    AUTH_UNAUTHORIZED = "AUTH_UNAUTHORIZED"

    # Network
    NETWORK_ERROR               = "NETWORK_ERROR"
    NETWORK_TIMEOUT             = "NETWORK_TIMEOUT"
    NETWORK_RETRY_LIMIT         = "NETWORK_RETRY_LIMIT"
    NETWORK_SERVICE_UNAVAILABLE = "NETWORK_SERVICE_UNAVAILABLE"

    # Circuit breaker
    CIRCUIT_OPEN = "CIRCUIT_OPEN"

    # Configuration
    CONFIG_INVALID_URL      = "CONFIG_INVALID_URL"
    CONFIG_MISSING_REQUIRED = "CONFIG_MISSING_REQUIRED"

    # Security
    SECURITY_PII_DETECTED      = "SECURITY_PII_DETECTED"
    SECURITY_SIGNATURE_INVALID = "SECURITY_SIGNATURE_INVALID"

    # Validation
    VALIDATION_ERROR = "VALIDATION_ERROR"

    # Maps each error code to a stable numeric identifier.
    NUMERIC_CODES = {
      INIT_FAILED                => 1000,
      INIT_TIMEOUT               => 1001,
      AUTH_INVALID_KEY           => 1100,
      AUTH_EXPIRED_KEY           => 1101,
      AUTH_MISSING_KEY           => 1102,
      AUTH_UNAUTHORIZED          => 1103,
      NETWORK_ERROR              => 1200,
      NETWORK_TIMEOUT            => 1201,
      NETWORK_RETRY_LIMIT        => 1202,
      NETWORK_SERVICE_UNAVAILABLE => 1203,
      CIRCUIT_OPEN               => 1300,
      CONFIG_INVALID_URL         => 1400,
      CONFIG_MISSING_REQUIRED    => 1401,
      SECURITY_PII_DETECTED      => 1500,
      SECURITY_SIGNATURE_INVALID => 1501,
      VALIDATION_ERROR           => 1600
    }.freeze

    # Error codes that represent transient / recoverable failures.
    RECOVERABLE_CODES = Set.new([
      NETWORK_ERROR,
      NETWORK_TIMEOUT,
      NETWORK_RETRY_LIMIT,
      NETWORK_SERVICE_UNAVAILABLE,
      CIRCUIT_OPEN
    ]).freeze

    # Returns the numeric code for a given error code string.
    #
    # @param code [String] the error code
    # @return [Integer, nil] the numeric code, or nil if unknown
    def self.numeric_code(code)
      NUMERIC_CODES[code]
    end

    # Returns true when the given error code represents a transient failure
    # that may succeed on retry.
    #
    # @param code [String] the error code
    # @return [Boolean]
    def self.recoverable?(code)
      RECOVERABLE_CODES.include?(code)
    end
  end
end

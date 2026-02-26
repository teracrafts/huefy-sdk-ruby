# frozen_string_literal: true

module Huefy
  # Default production base URL.
  DEFAULT_BASE_URL = "https://api.huefy.dev/api/v1/sdk"

  # Base URL used when running in local development mode.
  LOCAL_BASE_URL = "https://api.huefy.on/api/v1/sdk"

  # Default retry configuration.
  DEFAULT_RETRY_CONFIG = {
    max_retries: 3,
    base_delay: 1.0,
    max_delay: 30.0,
    retryable_status_codes: [408, 429, 500, 502, 503, 504]
  }.freeze

  # Default circuit breaker configuration.
  DEFAULT_CIRCUIT_BREAKER_CONFIG = {
    failure_threshold: 5,
    reset_timeout: 30.0,
    half_open_requests: 1
  }.freeze

  # Resolves the base URL by checking the HUEFY_MODE environment
  # variable. Returns {LOCAL_BASE_URL} when the value is "local"; otherwise
  # returns {DEFAULT_BASE_URL}.
  #
  # @return [String] the resolved base URL
  def self.resolve_base_url
    mode = ENV["HUEFY_MODE"]
    mode == "local" ? LOCAL_BASE_URL : DEFAULT_BASE_URL
  end

  # Configuration for the Huefy client.
  class Config
    # @return [String] the API key for authentication
    attr_reader :api_key

    # @return [String] the base URL of the API
    attr_reader :base_url

    # @return [Integer] HTTP request timeout in seconds
    attr_reader :timeout

    # @return [Hash] retry configuration
    attr_reader :retry_config

    # @return [Hash] circuit breaker configuration
    attr_reader :circuit_breaker_config

    # @return [String, nil] optional secondary API key for key rotation
    attr_reader :secondary_api_key

    # @return [Boolean] whether HMAC request signing is enabled
    attr_reader :enable_request_signing

    # @return [Boolean] whether error message sanitization is enabled
    attr_reader :enable_error_sanitization

    # @param api_key [String] the API key for authentication
    # @param base_url [String, nil] override the default base URL
    # @param timeout [Integer] HTTP request timeout in seconds
    # @param retry_config [Hash] retry configuration overrides
    # @param circuit_breaker_config [Hash] circuit breaker configuration overrides
    # @param secondary_api_key [String, nil] fallback API key
    # @param enable_request_signing [Boolean] enable HMAC request signing
    # @param enable_error_sanitization [Boolean] enable error sanitization
    def initialize(
      api_key:,
      base_url: nil,
      timeout: 30,
      retry_config: {},
      circuit_breaker_config: {},
      secondary_api_key: nil,
      enable_request_signing: false,
      enable_error_sanitization: true
    )
      @api_key = api_key
      @base_url = (base_url || Huefy.resolve_base_url).chomp("/")
      @timeout = timeout
      @retry_config = DEFAULT_RETRY_CONFIG.merge(retry_config)
      @circuit_breaker_config = DEFAULT_CIRCUIT_BREAKER_CONFIG.merge(circuit_breaker_config)
      @secondary_api_key = secondary_api_key
      @enable_request_signing = enable_request_signing
      @enable_error_sanitization = enable_error_sanitization

      validate_config!
    end

    private

    def validate_config!
      raise ArgumentError, "base_delay must be > 0" unless @retry_config[:base_delay].positive?
      raise ArgumentError, "max_delay must be >= base_delay" unless @retry_config[:max_delay] >= @retry_config[:base_delay]
      raise ArgumentError, "reset_timeout must be > 0" unless @circuit_breaker_config[:reset_timeout].positive?
      raise ArgumentError, "failure_threshold must be >= 1" unless @circuit_breaker_config[:failure_threshold] >= 1
    end
  end
end

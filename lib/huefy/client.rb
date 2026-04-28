# frozen_string_literal: true

module Huefy
  # Main client for the Huefy Ruby SDK.
  #
  # Create an instance with an API key and use it to interact with the
  # Huefy API.
  #
  # @example
  #   client = Teracrafts::Huefy::Client.new(api_key: "your-api-key")
  #   health = client.health_check
  #   puts health["status"]
  #   client.close
  class Client
    # @return [Config] the current client configuration
    attr_reader :config

    # Creates a new Huefy API client.
    #
    # @param api_key [String] the API key for authentication
    # @param base_url [String, nil] override the default base URL
    # @param timeout [Integer] HTTP request timeout in seconds (default: 30)
    # @param retry_config [Hash] retry configuration options
    # @param circuit_breaker_config [Hash] circuit breaker configuration options
    # @param secondary_api_key [String, nil] fallback API key for key rotation
    # @param enable_request_signing [Boolean] enable HMAC request signing
    # @param enable_error_sanitization [Boolean] enable error message sanitization
    # @raise [HuefyError] if the API key is missing or blank
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
      raise HuefyError.auth_missing_key("API key is required") if api_key.nil? || api_key.strip.empty?

      @config = Config.new(
        api_key: api_key,
        base_url: base_url,
        timeout: timeout,
        retry_config: retry_config,
        circuit_breaker_config: circuit_breaker_config,
        secondary_api_key: secondary_api_key,
        enable_request_signing: enable_request_signing,
        enable_error_sanitization: enable_error_sanitization
      )

      @http_client = Http::HttpClient.new(api_key, @config)
    end

    # Performs a health check against the Huefy API.
    #
    # Useful for verifying connectivity and that the API key is valid before
    # issuing business requests.
    #
    # @return [Hash] health response with "status", "timestamp", and optional "version"
    # @raise [HuefyError] on network or authentication failures
    def health_check
      @http_client.request("GET", "/health")
    end

    # Returns a read-only snapshot of the current configuration with
    # sensitive fields (API keys) omitted.
    #
    # @return [Hash] safe configuration snapshot
    def get_config
      {
        base_url: @config.base_url,
        timeout: @config.timeout,
        max_retries: @config.retry_config[:max_retries],
        failure_threshold: @config.circuit_breaker_config[:failure_threshold],
        enable_request_signing: @config.enable_request_signing,
        enable_error_sanitization: @config.enable_error_sanitization
      }.freeze
    end

    # Releases any resources held by the client.
    #
    # Call this when the client is no longer needed.
    def close
      @http_client.close
    end
  end
end

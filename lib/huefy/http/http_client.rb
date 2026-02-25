# frozen_string_literal: true

require "faraday"
require "json"

module Huefy
  module Http
    # Internal HTTP client that wraps Faraday with retry logic and circuit
    # breaking for the Huefy Ruby SDK.
    class HttpClient
      # @param api_key [String] the API key for authentication
      # @param config [Config] the client configuration
      def initialize(api_key, config)
        @api_key = api_key
        @config = config
        @retry_handler = RetryHandler.new(config.retry_config)
        @circuit_breaker = CircuitBreaker.new(**config.circuit_breaker_config)

        @connection = Faraday.new(url: config.base_url) do |f|
          f.options.timeout = config.timeout
          f.options.open_timeout = config.timeout
          f.headers["Content-Type"] = "application/json"
          f.headers["Accept"] = "application/json"
          f.headers["X-SDK-Version"] = Huefy::VERSION
          f.headers["User-Agent"] = "huefy-ruby/#{Huefy::VERSION}"
          f.headers["X-API-Key"] = api_key
          f.adapter Faraday.default_adapter
        end
      end

      # Sends an HTTP request to the API, wrapped with circuit breaker and
      # retry logic.
      #
      # @param method [String] HTTP method (GET, POST, PUT, PATCH, DELETE)
      # @param path [String] API path relative to the base URL
      # @param body [Hash, nil] optional request body
      # @param headers [Hash] additional headers
      # @return [Hash, String] parsed JSON response or raw body
      # @raise [HuefyError] on failure
      def request(method, path, body: nil, headers: {})
        extra_headers = headers.dup

        # Request signing
        if @config.enable_request_signing
          timestamp = Time.now.to_i.to_s
          extra_headers["X-Timestamp"] = timestamp
          extra_headers["X-Key-Id"] = @api_key[0, 8]

          payload = [method, path, timestamp, body ? JSON.generate(body) : ""].join("\n")
          signature = Security.generate_hmac_sha256(payload, @api_key)
          extra_headers["X-Signature"] = signature
        end

        serialized_body = body.is_a?(Hash) ? JSON.generate(body) : body

        @retry_handler.execute do
          @circuit_breaker.execute do
            perform_request(method, path, serialized_body, extra_headers)
          end
        end
      end

      # Resets the circuit breaker to its initial closed state.
      def close
        @circuit_breaker.reset
      end

      private

      def perform_request(method, path, body, extra_headers)
        response = @connection.run_request(
          method.downcase.to_sym,
          path,
          body,
          extra_headers
        )

        status = response.status

        unless (200..299).cover?(status)
          body_text = response.body.to_s
          raise HuefyError.from_response(status, body_text)
        end

        # 204 No Content
        return {} if status == 204

        JSON.parse(response.body)
      rescue Faraday::TimeoutError => e
        raise HuefyError.timeout_error(
          "Request to #{method} #{path} timed out after #{@config.timeout}s"
        )
      rescue Faraday::ConnectionFailed => e
        raise HuefyError.network_error(
          "Network error during #{method} #{path}",
          cause: e
        )
      rescue HuefyError
        raise
      rescue StandardError => e
        raise HuefyError.network_error(
          "Unexpected error during #{method} #{path}: #{e.message}",
          cause: e
        )
      end
    end
  end
end

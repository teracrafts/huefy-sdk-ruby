# frozen_string_literal: true

require "faraday"
require "json"
require "time"

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

        serialized_body = body.is_a?(Hash) ? JSON.generate(body) : (body || "")

        # Request signing
        if @config.enable_request_signing
          timestamp = (Time.now.to_f * 1000).to_i.to_s
          extra_headers["X-Timestamp"] = timestamp
          extra_headers["X-Key-Id"] = @api_key[0, 8]

          message = "#{timestamp}.#{serialized_body}"
          signature = Security.generate_hmac_sha256(message, @api_key)
          extra_headers["X-Signature"] = signature
        end

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
          if @config.enable_error_sanitization
            body_text = ErrorSanitizer.sanitize(body_text)
          end

          request_id = response.headers["x-request-id"]
          retry_after_raw = response.headers["retry-after"]
          retry_after_secs = nil
          if retry_after_raw
            parsed = retry_after_raw.to_f
            if parsed > 0
              retry_after_secs = parsed
            else
              begin
                retry_after_secs = [Time.httpdate(retry_after_raw) - Time.now, 0].max
              rescue ArgumentError
                # Ignore unparseable Retry-After values
              end
            end
          end

          raise HuefyError.from_response(status, body_text, request_id: request_id, retry_after: retry_after_secs)
        end

        # 204 No Content
        return {} if status == 204

        JSON.parse(response.body)
      rescue Faraday::TimeoutError => e
        msg = "Request to #{method} #{path} timed out after #{@config.timeout}s"
        msg = ErrorSanitizer.sanitize(msg) if @config.enable_error_sanitization
        raise HuefyError.timeout_error(msg)
      rescue Faraday::ConnectionFailed => e
        msg = "Network error during #{method} #{path}"
        msg = ErrorSanitizer.sanitize(msg) if @config.enable_error_sanitization
        raise HuefyError.network_error(msg, cause: e)
      rescue HuefyError
        raise
      rescue StandardError => e
        msg = "Unexpected error during #{method} #{path}: #{e.message}"
        msg = ErrorSanitizer.sanitize(msg) if @config.enable_error_sanitization
        raise HuefyError.network_error(msg, cause: e)
      end
    end
  end
end

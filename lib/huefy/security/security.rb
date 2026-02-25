# frozen_string_literal: true

require "openssl"
require "json"

module Huefy
  # Security utilities for the Huefy Ruby SDK.
  #
  # Provides PII detection, HMAC-SHA256 signing, and key classification helpers.
  module Security
    # Field name patterns that commonly indicate PII.
    PII_PATTERNS = %w[
      email phone telephone mobile
      ssn socialsecurity
      creditcard cardnumber cvv
      password passwd secret
      token apikey
      privatekey
      accesstoken
      refreshtoken
      authtoken
      address street zipcode postalcode
      dateofbirth dob birthdate
      passport driverlicense
      nationalid
      bankaccount
      routingnumber
      iban swift
    ].freeze

    # ---- PII Detection -------------------------------------------------------

    # Normalizes a field name by lowercasing and stripping hyphens/underscores.
    #
    # @param value [String]
    # @return [String]
    def self.normalize(value)
      value.downcase.gsub(/[-_]/, "")
    end

    # Returns true when +field_name+ looks like it could contain PII.
    #
    # Matching is case-insensitive and ignores hyphens/underscores.
    #
    # @param field_name [String]
    # @return [Boolean]
    def self.potential_pii_field?(field_name)
      normalized = normalize(field_name)
      PII_PATTERNS.any? { |pattern| normalized.include?(pattern) }
    end

    # Represents a detected PII field with its dot-delimited path.
    PIIDetection = Struct.new(:path, :field, keyword_init: true)

    # Recursively inspects +data+ and returns the paths of any keys that
    # look like PII fields.
    #
    # @param data [Hash] the data to inspect
    # @param prefix [String, nil] dot-delimited path prefix
    # @return [Array<PIIDetection>]
    def self.detect_potential_pii(data, prefix: nil)
      results = []

      data.each do |key, value|
        key_s = key.to_s
        path = prefix ? "#{prefix}.#{key_s}" : key_s

        if potential_pii_field?(key_s)
          results << PIIDetection.new(path: path, field: key_s)
        end

        if value.is_a?(Hash)
          results.concat(detect_potential_pii(value, prefix: path))
        end
      end

      results
    end

    # Logs a warning when +data+ contains fields that look like PII.
    #
    # @param data [Hash] the data to inspect
    # @param data_type [String] label for the data type (e.g. "request")
    # @param logger [#call, nil] optional logger proc; defaults to $stderr
    def self.warn_if_potential_pii(data, data_type, logger: nil)
      detections = detect_potential_pii(data)
      return if detections.empty?

      fields = detections.map(&:path).join(", ")
      message = "Potential PII detected in #{data_type} data. " \
                "Fields: [#{fields}]. " \
                "Please review whether this data should be transmitted and ensure " \
                "compliance with your data protection policies."

      if logger
        logger.call(message)
      else
        $stderr.puts("[WARNING] #{message}")
      end
    end

    # ---- Key Helpers ---------------------------------------------------------

    # Returns the first 8 characters of an API key, suitable for logging
    # without exposing the full secret.
    #
    # @param api_key [String]
    # @return [String]
    def self.get_key_id(api_key)
      api_key[0, 8] || ""
    end

    # Returns true when the key is a server-side key (prefixed with "srv_").
    #
    # @param api_key [String]
    # @return [Boolean]
    def self.server_key?(api_key)
      api_key.start_with?("srv_")
    end

    # Returns true when the key is a client-side key (prefixed with "sdk_" or "cli_").
    #
    # @param api_key [String]
    # @return [Boolean]
    def self.client_key?(api_key)
      api_key.start_with?("sdk_") || api_key.start_with?("cli_")
    end

    # ---- HMAC-SHA256 ---------------------------------------------------------

    # Generates an HMAC-SHA256 hex digest of +message+ using +key+.
    #
    # Uses OpenSSL for the underlying cryptographic operation.
    #
    # @param message [String] the message to sign
    # @param key [String] the secret key
    # @return [String] lowercase hex string of the HMAC digest
    def self.generate_hmac_sha256(message, key)
      OpenSSL::HMAC.hexdigest("SHA256", key, message)
    end

    # Signed payload containing data, signature, timestamp, and key identifier.
    SignedPayload = Struct.new(:data, :signature, :timestamp, :key_id, keyword_init: true)

    # Signs arbitrary data with an HMAC-SHA256 signature.
    #
    # @param data [Object] the data to sign (must be JSON-serializable)
    # @param api_key [String] the secret key
    # @param timestamp [Integer, nil] epoch ms timestamp; defaults to current time
    # @return [SignedPayload]
    def self.sign_payload(data, api_key, timestamp: nil)
      ts = timestamp || (Time.now.to_f * 1000).to_i
      message = JSON.generate({ data: data, timestamp: ts })
      signature = generate_hmac_sha256(message, api_key)

      SignedPayload.new(
        data: data,
        signature: signature,
        timestamp: ts,
        key_id: get_key_id(api_key)
      )
    end

    # Request signature containing the hex signature, timestamp, and key ID.
    RequestSignature = Struct.new(:signature, :timestamp, :key_id, keyword_init: true)

    # Creates an HMAC-SHA256 signature for an HTTP request body.
    #
    # The signed message has the form "<timestamp>.<body>" so that the
    # timestamp is bound to the payload.
    #
    # @param body [String] the raw request body
    # @param api_key [String] the secret key
    # @return [RequestSignature]
    def self.create_request_signature(body, api_key)
      timestamp = (Time.now.to_f * 1000).to_i
      message = "#{timestamp}.#{body}"
      signature = generate_hmac_sha256(message, api_key)

      RequestSignature.new(
        signature: signature,
        timestamp: timestamp,
        key_id: get_key_id(api_key)
      )
    end

    # Verifies an HMAC-SHA256 request signature.
    #
    # @param body [String] the raw request body that was signed
    # @param signature [String] the hex signature to verify
    # @param timestamp [Integer] the epoch-ms timestamp bound to the signature
    # @param api_key [String] the shared secret
    # @param max_age_ms [Integer] maximum acceptable age in ms (default: 300_000)
    # @return [Boolean] true when the signature is valid and within the age window
    def self.verify_request_signature(body, signature, timestamp, api_key, max_age_ms: 300_000)
      # Reject if the signature is too old (or from the future).
      now = (Time.now.to_f * 1000).to_i
      age = (now - timestamp).abs
      return false if age > max_age_ms

      message = "#{timestamp}.#{body}"
      expected = generate_hmac_sha256(message, api_key)

      # Constant-time comparison to avoid timing attacks.
      secure_compare(expected, signature)
    end

    # Constant-time string comparison.
    #
    # @param a [String]
    # @param b [String]
    # @return [Boolean]
    def self.secure_compare(a, b)
      return false unless a.bytesize == b.bytesize

      l = a.unpack("C*")
      r = b.unpack("C*")
      mismatch = 0
      l.zip(r) { |x, y| mismatch |= x ^ y }
      mismatch == 0
    end

    private_class_method :normalize, :secure_compare
  end
end

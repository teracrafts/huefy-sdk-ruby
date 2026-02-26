# frozen_string_literal: true

module Huefy
  module Models
    # Represents a request to send a single email.
    class SendEmailRequest
      # @return [String] the template identifier
      attr_reader :template_key

      # @return [String] the recipient email address
      attr_reader :recipient

      # @return [Hash<String, String>] template merge data
      attr_reader :data

      # @return [String, nil] optional email provider
      attr_reader :provider

      # @param template_key [String] the template identifier
      # @param recipient [String] the recipient email address
      # @param data [Hash<String, String>] template merge data
      # @param provider [String, nil] optional email provider
      def initialize(template_key:, recipient:, data:, provider: nil)
        @template_key = template_key
        @recipient = recipient
        @data = data
        @provider = provider
      end

      # Converts the request to a hash suitable for JSON serialization.
      #
      # @return [Hash] the request as a hash
      def to_h
        result = {
          "templateKey" => @template_key,
          "recipient" => @recipient,
          "data" => @data
        }
        result["providerType"] = @provider unless @provider.nil?
        result
      end
    end

    # Represents the response from sending an email.
    class SendEmailResponse
      # @return [Boolean] whether the send was successful
      attr_reader :success

      # @return [String] response message
      attr_reader :message

      # @return [String] the message ID from the provider
      attr_reader :message_id

      # @return [String] the provider that sent the email
      attr_reader :provider

      # @param success [Boolean]
      # @param message [String]
      # @param message_id [String]
      # @param provider [String]
      def initialize(success:, message:, message_id:, provider:)
        @success = success
        @message = message
        @message_id = message_id
        @provider = provider
      end

      # Creates a SendEmailResponse from a parsed JSON hash.
      #
      # @param hash [Hash] parsed API response
      # @return [SendEmailResponse]
      def self.from_hash(hash)
        new(
          success: hash["success"] || false,
          message: hash["message"] || "",
          message_id: hash["messageId"] || "",
          provider: hash["provider"] || ""
        )
      end
    end

    # Represents the result of a single email within a bulk operation.
    class BulkEmailResult
      # @return [String] the recipient email address
      attr_reader :email

      # @return [Boolean] whether this individual send succeeded
      attr_reader :success

      # @return [SendEmailResponse, nil] the response if successful
      attr_reader :result

      # @return [Hash, nil] error details if the send failed
      attr_reader :error

      # @param email [String]
      # @param success [Boolean]
      # @param result [SendEmailResponse, nil]
      # @param error [Hash, nil]
      def initialize(email:, success:, result: nil, error: nil)
        @email = email
        @success = success
        @result = result
        @error = error
      end

      # Creates a BulkEmailResult from a parsed JSON hash.
      #
      # @param hash [Hash]
      # @return [BulkEmailResult]
      def self.from_hash(hash)
        result = hash["result"] ? SendEmailResponse.from_hash(hash["result"]) : nil
        new(
          email: hash["email"] || "",
          success: hash["success"] || false,
          result: result,
          error: hash["error"]
        )
      end
    end

    # Represents the API health check response.
    class HealthResponse
      # @return [String] the health status
      attr_reader :status

      # @return [String] the server timestamp
      attr_reader :timestamp

      # @return [String] the API version
      attr_reader :version

      # @param status [String]
      # @param timestamp [String]
      # @param version [String]
      def initialize(status:, timestamp:, version:)
        @status = status
        @timestamp = timestamp
        @version = version
      end

      # Creates a HealthResponse from a parsed JSON hash.
      #
      # @param hash [Hash]
      # @return [HealthResponse]
      def self.from_hash(hash)
        new(
          status: hash["status"] || "",
          timestamp: hash["timestamp"] || "",
          version: hash["version"] || ""
        )
      end

      # Returns true when the API reports a healthy status.
      #
      # @return [Boolean]
      def healthy?
        status.downcase == "ok"
      end
    end
  end
end

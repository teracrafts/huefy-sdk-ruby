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

    # Represents the per-recipient status in a send-email response.
    RecipientStatus = Struct.new(:email, :status, :message_id, :error, :sent_at, keyword_init: true) do
      def self.from_hash(hash)
        new(
          email: hash["email"] || "",
          status: hash["status"] || "",
          message_id: hash["messageId"],
          error: hash["error"],
          sent_at: hash["sentAt"]
        )
      end
    end

    # Represents the data payload in a send-email response.
    SendEmailResponseData = Struct.new(:email_id, :status, :recipients, keyword_init: true) do
      def self.from_hash(hash)
        recipients = (hash["recipients"] || []).map { |r| RecipientStatus.from_hash(r) }
        new(
          email_id: hash["emailId"] || "",
          status: hash["status"] || "",
          recipients: recipients
        )
      end
    end

    # Represents the response from sending a single email.
    SendEmailResponse = Struct.new(:success, :data, :correlation_id, keyword_init: true) do
      def self.from_hash(hash)
        new(
          success: hash["success"] || false,
          data: SendEmailResponseData.from_hash(hash["data"] || {}),
          correlation_id: hash["correlationId"] || ""
        )
      end
    end

    # Represents a recipient entry in a bulk email request.
    BulkRecipient = Struct.new(:email, :type, :data, keyword_init: true) do
      def initialize(email:, type: "to", data: nil)
        super(email: email, type: type, data: data)
      end
    end

    # Represents the data payload in a send-bulk-emails response.
    SendBulkEmailsResponseData = Struct.new(
      :batch_id, :status, :template_key, :total_recipients,
      :success_count, :failure_count, :suppressed_count, :started_at, :recipients,
      keyword_init: true
    ) do
      def self.from_hash(hash)
        recipients = (hash["recipients"] || []).map { |r| RecipientStatus.from_hash(r) }
        new(
          batch_id: hash["batchId"] || "",
          status: hash["status"] || "",
          template_key: hash["templateKey"] || "",
          total_recipients: hash["totalRecipients"] || 0,
          success_count: hash["successCount"] || 0,
          failure_count: hash["failureCount"] || 0,
          suppressed_count: hash["suppressedCount"] || 0,
          started_at: hash["startedAt"] || "",
          recipients: recipients
        )
      end
    end

    # Represents the response from sending bulk emails.
    SendBulkEmailsResponse = Struct.new(:success, :data, :correlation_id, keyword_init: true) do
      def self.from_hash(hash)
        new(
          success: hash["success"] || false,
          data: SendBulkEmailsResponseData.from_hash(hash["data"] || {}),
          correlation_id: hash["correlationId"] || ""
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
      # @param hash [Hash] parsed API response
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

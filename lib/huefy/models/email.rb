# frozen_string_literal: true

module Teracrafts
  module Huefy
    module Models
    # Represents a request to send a single email.
      class SendEmailRequest
      # @return [String] the template identifier
      attr_reader :template_key

      # @return [String, SendEmailRecipient, Hash] the recipient payload
      attr_reader :recipient

      # @return [Hash<String, Object>] template merge data
      attr_reader :data

      # @return [String, nil] optional email provider
      attr_reader :provider

      # @param template_key [String] the template identifier
      # @param data [Hash<String, Object>] template merge data
      # @param recipient [String, SendEmailRecipient, Hash] the recipient email or recipient object
      # @param provider [String, nil] optional email provider
      def initialize(template_key:, data:, recipient:, provider: nil)
        @template_key = template_key
        @data = data
        @recipient = recipient
        @provider = provider
      end

      # Converts the request to a hash suitable for JSON serialization.
      #
      # @return [Hash] the request as a hash
      def to_h
        result = {
          "templateKey" => @template_key,
          "recipient" => serialize_recipient(@recipient),
          "data" => @data
        }
        result["providerType"] = @provider unless @provider.nil?
        result
      end

      private

      def serialize_recipient(recipient)
        case recipient
        when String
          recipient.strip
        when SendEmailRecipient
          recipient.to_h
        when Hash
          normalized = recipient.transform_keys(&:to_s)
          normalized["email"] = normalized["email"]&.strip if normalized["email"].is_a?(String)
          normalized["type"] = normalized["type"]&.strip&.downcase if normalized["type"].is_a?(String)
          normalized
        else
          recipient
        end
      end
    end

    # Represents the expanded recipient object accepted by the send-email API.
      class SendEmailRecipient
      attr_reader :email, :type, :data

      def initialize(email:, type: nil, data: nil)
        @email = email
        @type = type
        @data = data
      end

      def to_h
        {
          "email" => email.strip,
          "type" => type&.strip&.downcase,
          "data" => data
        }.compact
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
      :batch_id, :status, :template_key, :template_version, :sender_used, :sender_verified,
      :total_recipients, :processed_count, :success_count, :failure_count, :suppressed_count,
      :started_at, :completed_at, :recipients, :errors, :metadata,
      keyword_init: true
    ) do
      def self.from_hash(hash)
        recipients = (hash["recipients"] || []).map { |r| RecipientStatus.from_hash(r) }
        new(
          batch_id: hash["batchId"] || "",
          status: hash["status"] || "",
          template_key: hash["templateKey"] || "",
          template_version: hash["templateVersion"] || 0,
          sender_used: hash["senderUsed"] || "",
          sender_verified: hash["senderVerified"] || false,
          total_recipients: hash["totalRecipients"] || 0,
          processed_count: hash["processedCount"] || 0,
          success_count: hash["successCount"] || 0,
          failure_count: hash["failureCount"] || 0,
          suppressed_count: hash["suppressedCount"] || 0,
          started_at: hash["startedAt"] || "",
          completed_at: hash["completedAt"],
          recipients: recipients,
          errors: hash["errors"] || [],
          metadata: hash["metadata"]
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
        payload = hash["data"] || {}

        new(
          status: payload["status"] || "",
          timestamp: payload["timestamp"] || "",
          version: payload["version"] || ""
        )
      end

      # Returns true when the API reports a healthy status.
      #
      # @return [Boolean]
      def healthy?
        normalized = status.downcase
        normalized == "healthy" || normalized == "ok"
      end
      end
    end
  end
end

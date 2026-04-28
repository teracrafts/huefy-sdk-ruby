# frozen_string_literal: true

module Teracrafts
  module Huefy
    # Email-specific client that extends the base Client with email domain
  # operations.
  #
  # @example
  #   client = Teracrafts::Huefy::EmailClient.new(api_key: "your-api-key")
  #   response = client.send_email(
  #     template_key: "welcome",
  #     data: { "name" => "John" },
  #     recipient: Teracrafts::Huefy::Models::SendEmailRecipient.new(email: "john@example.com", type: "cc")
  #   )
  #   puts response.correlation_id
  #   client.close
    class EmailClient < Client
    SEND_EMAIL_PATH = "/emails/send"
    SEND_BULK_EMAIL_PATH = "/emails/send-bulk"
    HEALTH_PATH = "/health"

    # Sends a single email using the Huefy API.
    #
    # @param template_key [String] the template identifier
    # @param data [Hash<String, Object>] template merge data
    # @param recipient [String, Models::SendEmailRecipient, Hash] the recipient email or recipient object
    # @param provider [String, nil] optional email provider (ses, sendgrid, mailgun, mailchimp)
    # @return [Models::SendEmailResponse]
    # @raise [HuefyError] if validation or the request fails
    def send_email(template_key:, data:, recipient:, provider: nil)
      errors = Validators::EmailValidators.validate_send_email_input(template_key, data, recipient)
      unless errors.empty?
        raise HuefyError.new(
          errors.join("; "),
          code: ErrorCodes::VALIDATION_ERROR
        )
      end

      if provider && !Models::EmailProvider.valid?(provider)
        raise HuefyError.new(
          "Invalid provider: #{provider}. Must be one of: #{Models::EmailProvider::ALL.join(', ')}",
          code: ErrorCodes::VALIDATION_ERROR
        )
      end

      Security.warn_if_potential_pii(data, "email template")
      warn_if_potential_recipient_pii(recipient)

      request_obj = Models::SendEmailRequest.new(
        template_key: template_key,
        data: data,
        recipient: recipient,
        provider: provider
      )

      response = @http_client.request("POST", SEND_EMAIL_PATH, body: request_obj.to_h)

      Models::SendEmailResponse.from_hash(response)
    end

    # Sends emails to multiple recipients using the bulk API.
    #
    # @param template_key [String] the template identifier
    # @param recipients [Array<Models::BulkRecipient>] array of recipient objects
    # @param provider [String, nil] optional email provider (ses, sendgrid, mailgun, mailchimp)
    # @return [Models::SendBulkEmailsResponse]
    # @raise [HuefyError] if validation fails
    def send_bulk_emails(template_key:, recipients:, provider: nil)
      count_err = Validators::EmailValidators.validate_bulk_count(recipients.length)
      if count_err
        raise HuefyError.new(count_err, code: ErrorCodes::VALIDATION_ERROR)
      end

      template_err = Validators::EmailValidators.validate_template_key(template_key)
      if template_err
        raise HuefyError.new(template_err, code: ErrorCodes::VALIDATION_ERROR)
      end

      recipients.each_with_index do |r, i|
        recipient_err = Validators::EmailValidators.validate_bulk_recipient(r)
        if recipient_err
          raise HuefyError.new("recipients[#{i}]: #{recipient_err}", code: ErrorCodes::VALIDATION_ERROR)
        end
      end

      body = {
        templateKey: template_key.strip,
        recipients: recipients.map { |r|
          entry = {
            email: (r.respond_to?(:email) ? r.email : r[:email]).strip,
            type: (((r.respond_to?(:type) ? r.type : r[:type]) || "to").strip.downcase),
            data: r.respond_to?(:data) ? r.data : r[:data]
          }
          entry.compact
        }
      }
      body[:providerType] = provider if provider

      response = @http_client.request("POST", SEND_BULK_EMAIL_PATH, body: body)

      Models::SendBulkEmailsResponse.from_hash(response)
    end

    # Performs a typed health check against the API.
    #
    # @return [Models::HealthResponse]
    # @raise [HuefyError] if the request fails
    def email_health_check
      response = @http_client.request("GET", HEALTH_PATH)
      Models::HealthResponse.from_hash(response)
    end

    private

    def warn_if_potential_recipient_pii(recipient)
      recipient_data =
        case recipient
        when Models::SendEmailRecipient
          recipient.data
        when Hash
          recipient[:data] || recipient["data"]
        end

      return unless recipient_data.is_a?(Hash)

      Security.warn_if_potential_pii(recipient_data, "recipient data")
    end
    end
  end
end

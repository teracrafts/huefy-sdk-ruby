# frozen_string_literal: true

module Huefy
  # Email-specific client that extends the base Client with email domain
  # operations.
  #
  # @example
  #   client = Huefy::EmailClient.new(api_key: "your-api-key")
  #   response = client.send_email("welcome", { "name" => "John" }, "john@example.com")
  #   puts response.message_id
  #   client.close
  class EmailClient < Client
    SEND_EMAIL_PATH = "/emails/send"
    HEALTH_PATH = "/health"

    # Sends a single email using the Huefy API.
    #
    # @param template_key [String] the template identifier
    # @param data [Hash<String, String>] template merge data
    # @param recipient [String] the recipient email address
    # @param provider [String, nil] optional email provider (ses, sendgrid, mailgun, mailchimp)
    # @return [Models::SendEmailResponse]
    # @raise [HuefyError] if validation or the request fails
    def send_email(template_key, data, recipient, provider: nil)
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

      request_obj = Models::SendEmailRequest.new(
        template_key: template_key,
        recipient: recipient,
        data: data,
        provider: provider
      )

      response = @http_client.request("POST", SEND_EMAIL_PATH, body: request_obj.to_h)

      Models::SendEmailResponse.from_hash(response)
    end

    # Sends emails to multiple recipients using the same template.
    #
    # @param template_key [String] the template identifier
    # @param data [Hash<String, String>] template merge data
    # @param recipients [Array<String>] array of recipient email addresses
    # @param provider [String, nil] optional email provider
    # @return [Array<Models::BulkEmailResult>]
    # @raise [HuefyError] if bulk count validation fails
    def send_bulk_emails(template_key, data, recipients, provider: nil)
      count_err = Validators::EmailValidators.validate_bulk_count(recipients.length)
      if count_err
        raise HuefyError.new(count_err, code: ErrorCodes::VALIDATION_ERROR)
      end

      if provider && !Models::EmailProvider.valid?(provider)
        raise HuefyError.new(
          "Invalid provider: #{provider}. Must be one of: #{Models::EmailProvider::ALL.join(', ')}",
          code: ErrorCodes::VALIDATION_ERROR
        )
      end

      recipients.map do |recipient|
        begin
          response = send_email(template_key, data, recipient, provider: provider)
          Models::BulkEmailResult.new(
            email: recipient,
            success: true,
            result: response
          )
        rescue HuefyError => e
          Models::BulkEmailResult.new(
            email: recipient,
            success: false,
            error: { "message" => e.message, "code" => e.code }
          )
        end
      end
    end

    # Performs a typed health check against the API.
    #
    # @return [Models::HealthResponse]
    # @raise [HuefyError] if the request fails
    def email_health_check
      response = @http_client.request("GET", HEALTH_PATH)
      Models::HealthResponse.from_hash(response)
    end
  end
end

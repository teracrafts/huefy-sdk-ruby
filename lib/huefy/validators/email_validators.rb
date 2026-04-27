# frozen_string_literal: true

module Huefy
  module Validators
    # Validation utilities for email-related inputs.
    module EmailValidators
      EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.freeze
      VALID_RECIPIENT_TYPES = %w[to cc bcc].freeze
      MAX_EMAIL_LENGTH = 254
      MAX_TEMPLATE_KEY_LENGTH = 100
      MAX_BULK_EMAILS = 1000

      # Validates an email address.
      #
      # @param email [String] the email address to validate
      # @return [String, nil] error message, or nil if valid
      def self.validate_email(email)
        if email.nil? || !email.is_a?(String) || email.empty?
          return "Recipient email is required"
        end

        trimmed = email.strip
        if trimmed.length > MAX_EMAIL_LENGTH
          return "Email exceeds maximum length of #{MAX_EMAIL_LENGTH} characters"
        end

        unless EMAIL_REGEX.match?(trimmed)
          return "Invalid email address: #{trimmed}"
        end

        nil
      end

      # Validates a template key.
      #
      # @param template_key [String] the template key to validate
      # @return [String, nil] error message, or nil if valid
      def self.validate_template_key(template_key)
        if template_key.nil? || !template_key.is_a?(String) || template_key.empty?
          return "Template key is required"
        end

        trimmed = template_key.strip
        if trimmed.empty?
          return "Template key cannot be empty"
        end

        if trimmed.length > MAX_TEMPLATE_KEY_LENGTH
          return "Template key exceeds maximum length of #{MAX_TEMPLATE_KEY_LENGTH} characters"
        end

        nil
      end

      # Validates template data.
      #
      # @param data [Hash] the template data to validate
      # @return [String, nil] error message, or nil if valid
      def self.validate_email_data(data)
        if data.nil? || !data.is_a?(Hash)
          return "Template data must be a non-null hash"
        end

        nil
      end

      # Validates the count for a bulk email operation.
      #
      # @param count [Integer] the number of recipients
      # @return [String, nil] error message, or nil if valid
      def self.validate_bulk_count(count)
        if count <= 0
          return "At least one email is required"
        end

        if count > MAX_BULK_EMAILS
          return "Maximum of #{MAX_BULK_EMAILS} emails per bulk request"
        end

        nil
      end

      # Validates all inputs for a send email request.
      #
      # @param template_key [String]
      # @param data [Hash]
      # @param recipient [String, Huefy::Models::SendEmailRecipient, Hash]
      # @return [Array<String>] array of error messages; empty if valid
      def self.validate_send_email_input(template_key, data, recipient)
        errors = []
        key_err = validate_template_key(template_key)
        errors << key_err if key_err
        data_err = validate_email_data(data)
        errors << data_err if data_err
        email_err = validate_recipient(recipient)
        errors << email_err if email_err
        errors
      end

      def self.validate_recipient(recipient)
        case recipient
        when String
          validate_email(recipient)
        when Huefy::Models::SendEmailRecipient
          email_err = validate_email(recipient.email)
          return email_err if email_err

          type_err = validate_recipient_type(recipient.type)
          return type_err if type_err

          validate_recipient_data(recipient.data)
        when Hash
          email = recipient[:email] || recipient["email"]
          email_err = validate_email(email)
          return email_err if email_err

          type_err = validate_recipient_type(recipient[:type] || recipient["type"])
          return type_err if type_err

          validate_recipient_data(recipient[:data] || recipient["data"])
        else
          "Recipient must be a string or recipient object"
        end
      end

      def self.validate_bulk_recipient(recipient)
        case recipient
        when Models::BulkRecipient
          email_err = validate_email(recipient.email)
          return email_err if email_err

          type_err = validate_recipient_type(recipient.type)
          return type_err if type_err

          validate_recipient_data(recipient.data)
        when Hash
          email = recipient[:email] || recipient["email"]
          return "Recipient email is required" unless email.is_a?(String)

          email_err = validate_email(email)
          return email_err if email_err

          type_err = validate_recipient_type(recipient[:type] || recipient["type"])
          return type_err if type_err

          validate_recipient_data(recipient[:data] || recipient["data"])
        else
          "Recipient must be a BulkRecipient"
        end
      end

      def self.validate_recipient_type(recipient_type)
        return nil if recipient_type.nil?
        return "Recipient type must be one of: to, cc, bcc" unless recipient_type.is_a?(String)

        normalized = recipient_type.strip.downcase
        return nil if normalized.empty?
        return nil if VALID_RECIPIENT_TYPES.include?(normalized)

        "Recipient type must be one of: to, cc, bcc"
      end

      def self.validate_recipient_data(recipient_data)
        return nil if recipient_data.nil? || recipient_data.is_a?(Hash)

        "Recipient data must be an object"
      end
    end
  end
end

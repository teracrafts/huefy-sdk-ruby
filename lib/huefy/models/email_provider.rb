# frozen_string_literal: true

module Teracrafts
  module Huefy
    module Models
      module EmailProvider
      SES = "ses"
      SENDGRID = "sendgrid"
      MAILGUN = "mailgun"
      MAILCHIMP = "mailchimp"
      ALL = [SES, SENDGRID, MAILGUN, MAILCHIMP].freeze

      def self.valid?(provider)
        ALL.include?(provider)
      end
      end
    end
  end
end

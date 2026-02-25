# frozen_string_literal: true

module Huefy
  # Error message sanitizer that strips sensitive data before it leaves the SDK.
  #
  # Matches common patterns (file paths, IP addresses, API keys, email
  # addresses, database connection strings) and replaces them with safe
  # placeholder tokens.
  module ErrorSanitizer
    # Configuration controlling which patterns are sanitized.
    Config = Struct.new(:enabled, :preserve_original, keyword_init: true) do
      def initialize(enabled: true, preserve_original: false)
        super
      end
    end

    # Ordered list of sanitization rules. More specific patterns precede
    # generic ones to avoid partial matches.
    RULES = [
      # Database / service connection strings
      {
        name: "connection-string",
        pattern: /\b(?:postgres|postgresql|mysql|mongodb|mongodb\+srv|redis|rediss):\/\/[^\s'"`,;)\]}\n]+/i,
        replacement: "[CONNECTION_STRING]"
      },
      # SDK keys (sdk_...)
      {
        name: "sdk-key",
        pattern: /\bsdk_[A-Za-z0-9_\-]+/,
        replacement: "sdk_[REDACTED]"
      },
      # Server keys (srv_...)
      {
        name: "server-key",
        pattern: /\bsrv_[A-Za-z0-9_\-]+/,
        replacement: "srv_[REDACTED]"
      },
      # CLI keys (cli_...)
      {
        name: "cli-key",
        pattern: /\bcli_[A-Za-z0-9_\-]+/,
        replacement: "cli_[REDACTED]"
      },
      # Email addresses
      {
        name: "email",
        pattern: /\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b/,
        replacement: "[EMAIL]"
      },
      # IPv4 addresses
      {
        name: "ipv4",
        pattern: /\b(?:\d{1,3}\.){3}\d{1,3}\b/,
        replacement: "[IP]"
      },
      # Windows paths
      {
        name: "windows-path",
        pattern: /\b[A-Z]:\\(?:[^\s\\'",;)\]}\n]+\\)*[^\s\\'",;)\]}\n]*/i,
        replacement: "[PATH]"
      },
      # Unix paths (at least two segments)
      {
        name: "unix-path",
        pattern: %r{(?:/[A-Za-z0-9._\-]+){2,}(?:/[A-Za-z0-9._\-]*)*},
        replacement: "[PATH]"
      }
    ].freeze

    @default_config = Config.new

    class << self
      # Returns a copy of the current default sanitization configuration.
      #
      # @return [Config]
      def default_config
        @default_config.dup
      end

      # Replaces the default sanitization configuration.
      #
      # @param config [Config]
      def default_config=(config)
        @default_config = config
      end

      # Sanitizes a message by applying every matching rule.
      #
      # When config.enabled is false the original message is returned as-is.
      #
      # @param message [String] the raw error message
      # @param config [Config, nil] optional override configuration
      # @return [String] the sanitized message
      def sanitize(message, config: nil)
        cfg = config || @default_config
        return message unless cfg.enabled

        result = message.dup
        RULES.each do |rule|
          result.gsub!(rule[:pattern], rule[:replacement])
        end
        result
      end
    end
  end
end

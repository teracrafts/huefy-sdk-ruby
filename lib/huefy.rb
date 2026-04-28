# frozen_string_literal: true

require_relative "huefy/version"
require_relative "huefy/config"
require_relative "huefy/client"
require_relative "huefy/errors/error_codes"
require_relative "huefy/errors/huefy_error"
require_relative "huefy/errors/error_sanitizer"
require_relative "huefy/http/circuit_breaker"
require_relative "huefy/http/retry_handler"
require_relative "huefy/http/http_client"
require_relative "huefy/security/security"
require_relative "huefy/models/email_provider"
require_relative "huefy/models/email"
require_relative "huefy/validators/email_validators"
require_relative "huefy/huefy_email_client"

# Huefy Ruby SDK
#
# Provides a high-level client for interacting with the Huefy API,
# with built-in retry logic, circuit breaking, request signing, and error
# sanitization.
#
# @example Basic usage
#   client = Teracrafts::Huefy::Client.new(api_key: "your-api-key")
#   health = client.health_check
#   puts health["status"]
#   client.close
module Huefy
end

module Teracrafts
  Huefy = ::Huefy unless const_defined?(:Huefy, false)
end

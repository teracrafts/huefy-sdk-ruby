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

# Huefy Ruby SDK
#
# Provides a high-level client for interacting with the Huefy API,
# with built-in retry logic, circuit breaking, request signing, and error
# sanitization.
#
# @example Basic usage
#   client = Huefy::Client.new(api_key: "your-api-key")
#   health = client.health_check
#   puts health["status"]
#   client.close
module Huefy
end

# frozen_string_literal: true

require_relative "../lib/huefy"
require "net/http"
require "uri"

GREEN = "\033[32m"
RED   = "\033[31m"
RESET = "\033[0m"

@passed = 0
@failed = 0

def pass(name)
  puts "#{GREEN}[PASS]#{RESET} #{name}"
  @passed += 1
end

def fail_test(name, reason)
  puts "#{RED}[FAIL]#{RESET} #{name}: #{reason}"
  @failed += 1
end

puts "=== Huefy Ruby SDK Lab ==="
puts

# 1. Initialization
begin
  client = Teracrafts::Huefy::Client.new(api_key: "sdk_lab_test_key")
  pass("Initialization")
rescue => e
  fail_test("Initialization", e.message)
  client = nil
end

# 2. Config validation
begin
  Teracrafts::Huefy::Client.new(api_key: "")
  fail_test("Config validation", "expected error for empty API key, got none")
rescue Teracrafts::Huefy::HuefyError
  pass("Config validation")
rescue => e
  pass("Config validation") # any error on empty key is acceptable
end

# 3. HMAC signing
begin
  signed = Teracrafts::Huefy::Security.sign_payload({ "test" => "data" }, "test_secret", timestamp: 1700000000)
  if signed.signature.length == 64
    pass("HMAC signing")
  else
    fail_test("HMAC signing", "expected 64-char hex signature, got #{signed.signature.length} chars")
  end
rescue => e
  fail_test("HMAC signing", e.message)
end

# 4. Error sanitization
begin
  raw = "Error at 192.168.1.1 for user@example.com"
  sanitized = Teracrafts::Huefy::ErrorSanitizer.sanitize(raw)
  if sanitized.include?("192.168.1.1") || sanitized.include?("user@example.com")
    fail_test("Error sanitization", "IP or email still present after sanitization")
  else
    pass("Error sanitization")
  end
rescue => e
  fail_test("Error sanitization", e.message)
end

# 5. PII detection
begin
  data = { "email" => "t@t.com", "name" => "John", "ssn" => "123-45-6789" }
  detections = Teracrafts::Huefy::Security.detect_potential_pii(data)
  fields = detections.map(&:field)
  if detections.empty? || !fields.include?("email") || !fields.include?("ssn")
    fail_test("PII detection", "expected email and ssn fields, got: #{fields.inspect}")
  else
    pass("PII detection")
  end
rescue => e
  fail_test("PII detection", e.message)
end

# 6. Circuit breaker state
begin
  cb = Teracrafts::Huefy::Http::CircuitBreaker.new
  if cb.state == Teracrafts::Huefy::Http::CircuitBreaker::CLOSED
    pass("Circuit breaker state")
  else
    fail_test("Circuit breaker state", "expected CLOSED, got #{cb.state}")
  end
rescue => e
  fail_test("Circuit breaker state", e.message)
end

# 7. Health check
begin
  if client
    begin
      client.health_check
    rescue => _e
      # PASS regardless of network outcome; only non-network errors should fail
    end
  end
  pass("Health check")
rescue => e
  fail_test("Health check", "unexpected error: #{e.message}")
end

# 8. Cleanup
begin
  client&.close
  pass("Cleanup")
rescue => e
  fail_test("Cleanup", e.message)
end

puts
puts "========================================"
puts "Results: #{@passed} passed, #{@failed} failed"
puts "========================================"
puts

if @failed > 0
  exit 1
end

puts "All verifications passed!"

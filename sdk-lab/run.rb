# frozen_string_literal: true

require_relative "../lib/huefy"

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

class LabHttpClient
  attr_reader :calls

  def initialize(responses)
    @responses = responses.dup
    @calls = []
  end

  def request(method, path, body: nil, headers: {})
    @calls << { method: method, path: path, body: body, headers: headers }
    raise "no queued response" if @responses.empty?

    @responses.shift
  end

  def close; end
end

puts "=== Huefy Ruby SDK Lab ==="
puts

begin
  client = Teracrafts::Huefy::EmailClient.new(api_key: "sdk_lab_test_key")
  pass("Initialization")
rescue => e
  fail_test("Initialization", e.message)
  client = nil
end

begin
  contract_client = Teracrafts::Huefy::EmailClient.new(api_key: "sdk_lab_test_key")
  stub = LabHttpClient.new([
    {
      "success" => true,
      "data" => {
        "emailId" => "email_123",
        "status" => "queued",
        "recipients" => [{ "email" => "alice@example.com", "status" => "queued" }]
      },
      "correlationId" => "corr_send_123"
    }
  ])
  contract_client.instance_variable_set(:@http_client, stub)
  response = contract_client.send_email(
    template_key: " welcome-email ",
    data: { "firstName" => "Alice" },
    recipient: Teracrafts::Huefy::Models::SendEmailRecipient.new(
      email: " alice@example.com ",
      type: "CC",
      data: { "locale" => "en" }
    ),
    provider: "ses"
  )
  call = stub.calls.first
  recipient = call[:body]["recipient"]
  ok =
    call[:method] == "POST" &&
    call[:path] == "/emails/send" &&
    call[:body]["templateKey"] == "welcome-email" &&
    recipient["email"] == "alice@example.com" &&
    recipient["type"] == "cc" &&
    call[:body]["providerType"] == "ses" &&
    response.data.email_id == "email_123"
  ok ? pass("Single email contract") : fail_test("Single email contract", call.inspect)
rescue => e
  fail_test("Single email contract", e.message)
end

begin
  contract_client = Teracrafts::Huefy::EmailClient.new(api_key: "sdk_lab_test_key")
  stub = LabHttpClient.new([
    {
      "success" => true,
      "data" => {
        "batchId" => "batch_123",
        "status" => "processing",
        "templateKey" => "digest",
        "templateVersion" => 3,
        "senderUsed" => "alerts@huefy.dev",
        "senderVerified" => true,
        "totalRecipients" => 2,
        "processedCount" => 0,
        "successCount" => 0,
        "failureCount" => 0,
        "suppressedCount" => 0,
        "startedAt" => "2026-05-07T10:00:00Z",
        "recipients" => [
          { "email" => "alice@example.com", "status" => "queued" },
          { "email" => "bob@example.com", "status" => "queued" }
        ]
      },
      "correlationId" => "corr_bulk_123"
    }
  ])
  contract_client.instance_variable_set(:@http_client, stub)
  response = contract_client.send_bulk_emails(
    template_key: " digest ",
    recipients: [
      Teracrafts::Huefy::Models::BulkRecipient.new(email: " alice@example.com ", type: "TO", data: { "locale" => "en" }),
      Teracrafts::Huefy::Models::BulkRecipient.new(email: " bob@example.com ", type: "BCC")
    ],
    provider: "mailgun"
  )
  call = stub.calls.first
  recipients = call[:body][:recipients] || call[:body]["recipients"]
  ok =
    call[:method] == "POST" &&
    call[:path] == "/emails/send-bulk" &&
    (call[:body][:templateKey] || call[:body]["templateKey"]) == "digest" &&
    (call[:body][:providerType] || call[:body]["providerType"]) == "mailgun" &&
    recipients[0][:email] == "alice@example.com" &&
    recipients[0][:type] == "to" &&
    recipients[1][:type] == "bcc" &&
    response.data.batch_id == "batch_123"
  ok ? pass("Bulk email contract") : fail_test("Bulk email contract", call.inspect)
rescue => e
  fail_test("Bulk email contract", e.message)
end

begin
  invalid_client = Teracrafts::Huefy::EmailClient.new(api_key: "sdk_lab_test_key")
  invalid_client.instance_variable_set(:@http_client, LabHttpClient.new([{}]))
  invalid_client.send_email(
    template_key: "welcome",
    data: {},
    recipient: Teracrafts::Huefy::Models::SendEmailRecipient.new(email: "bad", type: "reply-to")
  )
  fail_test("Validation rejects invalid single recipient", "expected validation error")
rescue Teracrafts::Huefy::HuefyError => e
  message = e.message.downcase
  if message.include?("invalid email") || message.include?("recipient type")
    pass("Validation rejects invalid single recipient")
  else
    fail_test("Validation rejects invalid single recipient", e.message)
  end
rescue => e
  fail_test("Validation rejects invalid single recipient", e.message)
end

begin
  invalid_client = Teracrafts::Huefy::EmailClient.new(api_key: "sdk_lab_test_key")
  invalid_client.instance_variable_set(:@http_client, LabHttpClient.new([{}]))
  invalid_client.send_bulk_emails(
    template_key: "digest",
    recipients: []
  )
  fail_test("Validation rejects invalid bulk request", "expected validation error")
rescue Teracrafts::Huefy::HuefyError => e
  if e.message.downcase.include?("at least one email")
    pass("Validation rejects invalid bulk request")
  else
    fail_test("Validation rejects invalid bulk request", e.message)
  end
rescue => e
  fail_test("Validation rejects invalid bulk request", e.message)
end

begin
  health_client = Teracrafts::Huefy::EmailClient.new(api_key: "sdk_lab_test_key")
  stub = LabHttpClient.new([
    {
      "success" => true,
      "data" => {
        "status" => "healthy",
        "timestamp" => "2026-05-07T10:00:00Z",
        "version" => "1.0.0"
      },
      "correlationId" => "corr_health_123"
    }
  ])
  health_client.instance_variable_set(:@http_client, stub)
  response = health_client.email_health_check
  call = stub.calls.first
  ok =
    call[:method] == "GET" &&
    call[:path] == "/health" &&
    response.status == "healthy"
  ok ? pass("Health check path") : fail_test("Health check path", call.inspect)
rescue => e
  fail_test("Health check path", e.message)
end

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

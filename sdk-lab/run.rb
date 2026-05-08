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

def live_mode?
  ENV.fetch("HUEFY_SDK_LAB_MODE", "").downcase == "live"
end

def require_env(name)
  value = ENV[name].to_s.strip
  raise "#{name} is required in live mode" if value.empty?

  value
end

def live_provider
  provider = ENV.fetch("HUEFY_SDK_LIVE_PROVIDER", "").strip.downcase
  return nil if provider.empty?

  provider
end

def print_summary
  puts
  puts "========================================"
  puts "Results: #{@passed} passed, #{@failed} failed"
  puts "========================================"
  puts

  exit 1 if @failed > 0

  puts "All verifications passed!"
  exit 0
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

if live_mode?
  begin
    client = Teracrafts::Huefy::EmailClient.new(
      api_key: require_env("HUEFY_SDK_LIVE_API_KEY"),
      base_url: require_env("HUEFY_SDK_LIVE_BASE_URL")
    )
    pass("Initialization")
  rescue => e
    fail_test("Initialization", e.message)
    client = nil
  end

  if client
    recipient = require_env("HUEFY_SDK_LIVE_RECIPIENT")
    template_key = require_env("HUEFY_SDK_LIVE_TEMPLATE_KEY")
    provider = live_provider

    begin
      response = client.send_email(
        template_key: template_key,
        data: { "FirstName" => "SDK Live" },
        recipient: recipient,
        provider: provider
      )
      if response.success
        pass("Single email live behavior")
      else
        fail_test("Single email live behavior", "expected successful live send")
      end
    rescue => e
      fail_test("Single email live behavior", e.message)
    end

    begin
      response = client.send_bulk_emails(
        template_key: template_key,
        recipients: [Teracrafts::Huefy::Models::BulkRecipient.new(email: recipient, type: "TO")],
        provider: provider
      )
      if response.success && response.data.total_recipients.to_i >= 1
        pass("Bulk email live behavior")
      else
        fail_test("Bulk email live behavior", "expected successful live bulk send")
      end
    rescue => e
      fail_test("Bulk email live behavior", e.message)
    end

    begin
      client.send_email(
        template_key: template_key,
        data: {},
        recipient: Teracrafts::Huefy::Models::SendEmailRecipient.new(email: "bad", type: "reply-to")
      )
      fail_test("Validation rejects invalid single recipient", "expected validation error")
    rescue Teracrafts::Huefy::HuefyError
      pass("Validation rejects invalid single recipient")
    rescue => e
      fail_test("Validation rejects invalid single recipient", e.message)
    end

    begin
      client.send_bulk_emails(
        template_key: template_key,
        recipients: [Teracrafts::Huefy::Models::BulkRecipient.new(email: "bad-email", type: "reply-to")]
      )
      fail_test("Validation rejects invalid bulk request", "expected validation error")
    rescue Teracrafts::Huefy::HuefyError
      pass("Validation rejects invalid bulk request")
    rescue => e
      fail_test("Validation rejects invalid bulk request", e.message)
    end

    begin
      response = client.email_health_check
      if response.status == "healthy"
        pass("Health check path")
      else
        fail_test("Health check path", "expected healthy live response")
      end
    rescue => e
      fail_test("Health check path", e.message)
    end

    begin
      client.close
      pass("Cleanup")
    rescue => e
      fail_test("Cleanup", e.message)
    end
  end

  print_summary
end

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

print_summary

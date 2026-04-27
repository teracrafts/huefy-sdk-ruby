# frozen_string_literal: true

require "spec_helper"

RSpec.describe Huefy::EmailClient do
  let(:send_email_response) do
    {
      "success" => true,
      "correlationId" => "corr-123",
      "data" => {
        "emailId" => "email-abc",
        "status" => "sent",
        "recipients" => [{ "email" => "john@example.com", "status" => "sent" }]
      }
    }
  end

  let(:bulk_response) do
    {
      "success" => true,
      "correlationId" => "corr-456",
      "data" => {
        "batchId" => "batch-xyz",
        "status" => "completed",
        "templateKey" => "welcome",
        "totalRecipients" => 2,
        "successCount" => 2,
        "failureCount" => 0,
        "suppressedCount" => 0,
        "startedAt" => "2026-04-24T20:00:00Z",
        "recipients" => [
          { "email" => "alice@example.com", "status" => "sent" },
          { "email" => "bob@example.com", "status" => "sent" }
        ]
      }
    }
  end

  def make_client(response)
    client = described_class.new(api_key: "sdk_test_key")
    http = instance_double(Huefy::Http::HttpClient)
    allow(http).to receive(:request).and_return(response)
    client.instance_variable_set(:@http_client, http)
    client
  end

  # --- send_email keyword args ---

  describe "#send_email" do
    it "accepts keyword arguments and returns a SendEmailResponse" do
      client = make_client(send_email_response)
      response = client.send_email(
        template_key: "welcome",
        data: { "name" => "John" },
        recipient: "john@example.com"
      )
      expect(response.success).to be true
      expect(response.data.email_id).to eq("email-abc")
      expect(response.correlation_id).to eq("corr-123")
    end

    it "returns correct recipient status" do
      client = make_client(send_email_response)
      response = client.send_email(
        template_key: "welcome",
        data: { "name" => "John" },
        recipient: "john@example.com"
      )
      expect(response.data.recipients.first.email).to eq("john@example.com")
      expect(response.data.recipients.first.status).to eq("sent")
    end

    it "accepts a recipient object" do
      client = make_client(send_email_response)
      response = client.send_email(
        template_key: "welcome",
        data: { "name" => "John" },
        recipient: Huefy::Models::SendEmailRecipient.new(
          email: "john@example.com",
          type: "cc",
          data: { "locale" => "en" }
        )
      )
      expect(response.success).to be true
      expect(response.data.recipients.first.email).to eq("john@example.com")
    end

    it "raises HuefyError for empty template_key" do
      client = make_client(send_email_response)
      expect {
        client.send_email(template_key: "", data: {}, recipient: "john@example.com")
      }.to raise_error(Huefy::HuefyError)
    end

    it "raises HuefyError for invalid recipient" do
      client = make_client(send_email_response)
      expect {
        client.send_email(template_key: "welcome", data: {}, recipient: "not-an-email")
      }.to raise_error(Huefy::HuefyError)
    end

    it "raises HuefyError for invalid provider" do
      client = make_client(send_email_response)
      expect {
        client.send_email(
          template_key: "welcome",
          data: {},
          recipient: "john@example.com",
          provider: "unknown-provider"
        )
      }.to raise_error(Huefy::HuefyError)
    end
  end

  # --- send_bulk_emails keyword args ---

  describe "#send_bulk_emails" do
    it "accepts keyword arguments and returns a SendBulkEmailsResponse" do
      client = make_client(bulk_response)
      response = client.send_bulk_emails(
        template_key: "welcome",
        recipients: [
          Huefy::Models::BulkRecipient.new(email: "alice@example.com", data: { "name" => "Alice" }),
          Huefy::Models::BulkRecipient.new(email: "bob@example.com", data: { "name" => "Bob" })
        ]
      )
      expect(response.success).to be true
      expect(response.data.batch_id).to eq("batch-xyz")
      expect(response.data.total_recipients).to eq(2)
      expect(response.data.success_count).to eq(2)
    end

    it "raises HuefyError when recipients is empty" do
      client = make_client(bulk_response)
      expect {
        client.send_bulk_emails(template_key: "welcome", recipients: [])
      }.to raise_error(Huefy::HuefyError)
    end

    it "raises HuefyError when a recipient email is invalid" do
      client = make_client(bulk_response)
      expect {
        client.send_bulk_emails(
          template_key: "welcome",
          recipients: [Huefy::Models::BulkRecipient.new(email: "not-valid")]
        )
      }.to raise_error(Huefy::HuefyError)
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe Huefy::Security do
  describe ".potential_pii_field?" do
    %w[email phone ssn credit_card password].each do |field|
      it "detects '#{field}' as potential PII" do
        expect(described_class.potential_pii_field?(field)).to be true
      end
    end

    %w[name age color flagKey].each do |field|
      it "returns false for safe field '#{field}'" do
        expect(described_class.potential_pii_field?(field)).to be false
      end
    end

    it "handles case-insensitive and separator variants" do
      expect(described_class.potential_pii_field?("EMAIL")).to be true
      expect(described_class.potential_pii_field?("Email")).to be true
      expect(described_class.potential_pii_field?("e-mail")).to be true
      expect(described_class.potential_pii_field?("e_mail")).to be true
      expect(described_class.potential_pii_field?("Phone")).to be true
      expect(described_class.potential_pii_field?("PHONE")).to be true
      expect(described_class.potential_pii_field?("phone_number")).to be true
      expect(described_class.potential_pii_field?("creditCard")).to be true
    end
  end

  describe ".detect_potential_pii" do
    it "finds nested PII fields" do
      data = {
        "user" => {
          "name" => "John",
          "email" => "john@example.com",
          "profile" => {
            "phone" => "555-1234",
            "bio" => "Hello"
          }
        }
      }

      results = described_class.detect_potential_pii(data)
      expect(results.length).to be >= 2

      paths = results.map(&:path)
      expect(paths.any? { |p| p.include?("email") }).to be true
      expect(paths.any? { |p| p.include?("phone") }).to be true
    end

    it "returns empty array for safe data" do
      data = {
        "id" => 123,
        "status" => "active",
        "config" => {
          "theme" => "dark",
          "locale" => "en-US"
        }
      }

      results = described_class.detect_potential_pii(data)
      expect(results).to be_empty
    end
  end

  describe ".get_key_id" do
    it "returns first 8 characters" do
      expect(described_class.get_key_id("sdk_abc12345xyz")).to eq("sdk_abc1")
    end

    it "handles short keys" do
      expect(described_class.get_key_id("abc")).to eq("abc")
      expect(described_class.get_key_id("")).to eq("")
    end
  end

  describe "key classification" do
    it "classifies server keys correctly" do
      expect(described_class.server_key?("srv_abc123")).to be true
      expect(described_class.server_key?("sdk_abc123")).to be false
      expect(described_class.server_key?("cli_abc123")).to be false
      expect(described_class.server_key?("random_key")).to be false
    end

    it "classifies client keys correctly" do
      expect(described_class.client_key?("sdk_abc123")).to be true
      expect(described_class.client_key?("cli_abc123")).to be true
      expect(described_class.client_key?("srv_abc123")).to be false
      expect(described_class.client_key?("random_key")).to be false
    end
  end

  describe ".generate_hmac_sha256" do
    it "produces consistent hex output" do
      key = "test-secret-key"
      data = "hello world"

      hash1 = described_class.generate_hmac_sha256(data, key)
      hash2 = described_class.generate_hmac_sha256(data, key)

      expect(hash1).to eq(hash2)
      expect(hash1).to match(/\A[a-f0-9]{64}\z/)
    end

    it "produces different output for different data" do
      key = "test-secret-key"

      hash1 = described_class.generate_hmac_sha256("data-one", key)
      hash2 = described_class.generate_hmac_sha256("data-two", key)

      expect(hash1).not_to eq(hash2)
    end

    it "produces different output for different keys" do
      data = "same-data"

      hash1 = described_class.generate_hmac_sha256(data, "key-one")
      hash2 = described_class.generate_hmac_sha256(data, "key-two")

      expect(hash1).not_to eq(hash2)
    end
  end

  describe ".create_request_signature" do
    it "returns signature, timestamp, and key_id" do
      api_key = "sdk_abc12345xyz"
      body = '{"to":"user@example.com","subject":"Hello"}'

      result = described_class.create_request_signature(body, api_key)

      expect(result.signature).to be_a(String)
      expect(result.signature.length).to be > 0
      expect(result.timestamp).to be_a(Integer)
      expect(result.timestamp).to be > 0
      expect(result.key_id).to eq("sdk_abc1")
    end
  end

  describe ".verify_request_signature" do
    it "validates correct signatures" do
      api_key = "sdk_abc12345xyz"
      body = '{"to":"user@example.com","subject":"Test"}'

      sig = described_class.create_request_signature(body, api_key)
      is_valid = described_class.verify_request_signature(
        body, sig.signature, sig.timestamp, api_key
      )

      expect(is_valid).to be true
    end

    it "rejects tampered body" do
      api_key = "sdk_abc12345xyz"
      original_body = '{"to":"user@example.com","subject":"Test"}'
      tampered_body = '{"to":"attacker@evil.com","subject":"Test"}'

      sig = described_class.create_request_signature(original_body, api_key)
      is_valid = described_class.verify_request_signature(
        tampered_body, sig.signature, sig.timestamp, api_key
      )

      expect(is_valid).to be false
    end

    it "rejects expired signatures" do
      api_key = "sdk_abc12345xyz"
      body = '{"to":"user@example.com","subject":"Test"}'

      sig = described_class.create_request_signature(body, api_key)

      # Use a timestamp far in the past (10 minutes ago)
      expired_timestamp = (Time.now.to_f * 1000).to_i - (10 * 60 * 1000)

      is_valid = described_class.verify_request_signature(
        body, sig.signature, expired_timestamp, api_key,
        max_age_ms: 300_000 # 5 minute max age
      )

      expect(is_valid).to be false
    end
  end
end

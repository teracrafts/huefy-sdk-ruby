# frozen_string_literal: true

require "spec_helper"

RSpec.describe Huefy::Validators::EmailValidators do
  describe ".validate_email" do
    it "accepts a valid email" do
      expect(described_class.validate_email("user@example.com")).to be_nil
    end

    it "rejects an empty string" do
      result = described_class.validate_email("")
      expect(result).to include("required")
    end

    it "rejects nil" do
      result = described_class.validate_email(nil)
      expect(result).to include("required")
    end

    it "rejects an invalid email without domain" do
      result = described_class.validate_email("user@")
      expect(result).to include("Invalid email")
    end

    it "rejects an email without @ sign" do
      result = described_class.validate_email("not-an-email")
      expect(result).to include("Invalid email")
    end

    it "rejects an overly long email" do
      long_email = "a" * 250 + "@b.co"
      result = described_class.validate_email(long_email)
      expect(result).to include("maximum length")
    end

    it "trims whitespace before validating" do
      expect(described_class.validate_email("  user@example.com  ")).to be_nil
    end
  end

  describe ".validate_template_key" do
    it "accepts a valid template key" do
      expect(described_class.validate_template_key("welcome-email")).to be_nil
    end

    it "rejects an empty string" do
      result = described_class.validate_template_key("")
      expect(result).to include("required")
    end

    it "rejects nil" do
      result = described_class.validate_template_key(nil)
      expect(result).to include("required")
    end

    it "rejects a whitespace-only string" do
      result = described_class.validate_template_key("   ")
      expect(result).to include("empty")
    end

    it "rejects an overly long template key" do
      long_key = "a" * 101
      result = described_class.validate_template_key(long_key)
      expect(result).to include("maximum length")
    end
  end

  describe ".validate_email_data" do
    it "accepts valid data" do
      expect(described_class.validate_email_data({ "name" => "John" })).to be_nil
    end

    it "accepts an empty hash" do
      expect(described_class.validate_email_data({})).to be_nil
    end

    it "rejects nil" do
      result = described_class.validate_email_data(nil)
      expect(result).to include("non-null hash")
    end

    it "rejects a non-hash value" do
      result = described_class.validate_email_data("not a hash")
      expect(result).to include("non-null hash")
    end

    it "rejects non-string values" do
      result = described_class.validate_email_data({ "count" => 5 })
      expect(result).to include("must be a string")
    end

    it "rejects array values" do
      result = described_class.validate_email_data({ "items" => %w[a b] })
      expect(result).to include("must be a string")
    end
  end

  describe ".validate_bulk_count" do
    it "accepts a valid count" do
      expect(described_class.validate_bulk_count(10)).to be_nil
    end

    it "accepts exactly 100" do
      expect(described_class.validate_bulk_count(100)).to be_nil
    end

    it "rejects zero" do
      result = described_class.validate_bulk_count(0)
      expect(result).to include("At least one")
    end

    it "rejects negative count" do
      result = described_class.validate_bulk_count(-1)
      expect(result).to include("At least one")
    end

    it "rejects over 100" do
      result = described_class.validate_bulk_count(101)
      expect(result).to include("Maximum of 100")
    end
  end

  describe ".validate_send_email_input" do
    it "returns empty array for valid input" do
      errors = described_class.validate_send_email_input("tpl", { "name" => "John" }, "user@test.com")
      expect(errors).to be_empty
    end

    it "returns multiple errors for multiple invalid inputs" do
      errors = described_class.validate_send_email_input("", nil, "bad")
      expect(errors.length).to be > 1
    end

    it "returns a single error for one invalid field" do
      errors = described_class.validate_send_email_input("tpl", { "name" => "John" }, "bad")
      expect(errors.length).to eq(1)
    end
  end
end

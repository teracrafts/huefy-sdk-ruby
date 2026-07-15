# frozen_string_literal: true

require "spec_helper"

RSpec.describe Teracrafts::Huefy::HuefyError do
  describe ".from_response" do
    it "maps 402 quota exhaustion to a non-recoverable quota error" do
      error = described_class.from_response(
        402,
        "{\"error\":\"Quota exceeded\",\"code\":\"INSUFFICIENT_QUOTA\"}",
        request_id: "req_123"
      )

      expect(error.code).to eq(Teracrafts::Huefy::ErrorCodes::INSUFFICIENT_QUOTA)
      expect(error.numeric_code).to eq(1700)
      expect(error.status_code).to eq(402)
      expect(error.request_id).to eq("req_123")
      expect(error.recoverable?).to be(false)
      expect(error.message).to include("Quota exceeded")
    end
  end
end

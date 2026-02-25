# frozen_string_literal: true

require "spec_helper"

RSpec.describe Huefy::Http::CircuitBreaker do
  subject(:breaker) { described_class.new(**config) }

  let(:config) { { failure_threshold: 3, reset_timeout: 0.1, half_open_requests: 1 } }

  describe "with default behaviour" do
    it "starts in closed state" do
      expect(breaker.current_state).to eq(:closed)
    end

    it "transitions to open after failure threshold" do
      config[:failure_threshold].times do
        expect {
          breaker.execute { raise Huefy::HuefyError.network_error("fail") }
        }.to raise_error(Huefy::HuefyError)
      end

      expect(breaker.current_state).to eq(:open)
    end

    it "rejects calls with circuit-open error when open" do
      config[:failure_threshold].times do
        begin
          breaker.execute { raise Huefy::HuefyError.network_error("fail") }
        rescue Huefy::HuefyError
          # expected
        end
      end

      expect(breaker.current_state).to eq(:open)

      expect {
        breaker.execute { "ok" }
      }.to raise_error(Huefy::HuefyError) { |e|
        expect(e.code).to eq(Huefy::ErrorCodes::CIRCUIT_OPEN)
      }
    end

    it "resets to closed state" do
      config[:failure_threshold].times do
        begin
          breaker.execute { raise Huefy::HuefyError.network_error("fail") }
        rescue Huefy::HuefyError
          # expected
        end
      end

      expect(breaker.current_state).to eq(:open)

      breaker.reset

      expect(breaker.current_state).to eq(:closed)
    end

    it "returns correct statistics" do
      2.times { breaker.execute { "ok" } }

      begin
        breaker.execute { raise Huefy::HuefyError.network_error("fail") }
      rescue Huefy::HuefyError
        # expected
      end

      stats = breaker.stats
      expect(stats[:successes]).to eq(2)
      expect(stats[:failures]).to eq(1)
      expect(stats[:state]).to eq(:closed)
    end
  end

  describe "state transitions" do
    it "transitions to half-open after reset timeout" do
      config[:failure_threshold].times do
        begin
          breaker.execute { raise Huefy::HuefyError.network_error("fail") }
        rescue Huefy::HuefyError
          # expected
        end
      end

      expect(breaker.current_state).to eq(:open)

      sleep(0.15) # Wait past reset timeout

      expect(breaker.current_state).to eq(:half_open)
    end

    it "transitions from half-open to closed on success" do
      config[:failure_threshold].times do
        begin
          breaker.execute { raise Huefy::HuefyError.network_error("fail") }
        rescue Huefy::HuefyError
          # expected
        end
      end

      sleep(0.15) # Wait past reset timeout

      result = breaker.execute { "recovered" }
      expect(result).to eq("recovered")
      expect(breaker.current_state).to eq(:closed)
    end

    it "transitions from half-open back to open on failure" do
      config[:failure_threshold].times do
        begin
          breaker.execute { raise Huefy::HuefyError.network_error("fail") }
        rescue Huefy::HuefyError
          # expected
        end
      end

      sleep(0.15) # Wait past reset timeout

      expect {
        breaker.execute { raise Huefy::HuefyError.network_error("still failing") }
      }.to raise_error(Huefy::HuefyError)

      expect(breaker.current_state).to eq(:open)
    end
  end
end

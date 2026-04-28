# huefy

Official Ruby SDK for [Huefy](https://huefy.dev) — transactional email delivery made simple.

## Installation

```bash
gem install huefy
```

Or add to your `Gemfile`:

```ruby
gem 'huefy', '~> 1.0'
```

Then:

```bash
bundle install
```

## Requirements

- Runtime: Ruby 3.0+
- Development toolchain: Ruby 4.0.3 and Bundler 4

The gem itself still targets Ruby 3.0+ at runtime. The checked-in `Gemfile.lock` is maintained with Bundler `4.0.10`, and `.ruby-version` pins the contributor toolchain to Ruby `4.0.3`. On macOS, the default system Ruby is typically too old for that development workflow.

## Quick Start

```ruby
require "teracrafts/huefy"

client = Teracrafts::Huefy::EmailClient.new(
  api_key: 'sdk_your_api_key'
)

response = client.send_email(
  template_key: 'welcome-email',
  recipient: Teracrafts::Huefy::Models::SendEmailRecipient.new(
    email: 'alice@example.com',
    type: 'cc',
    data: { locale: 'en' }
  ),
  data: { first_name: 'Alice', trial_days: '14' }
)

puts "Message ID: #{response.data.email_id}"
```

## Key Features

- **Idiomatic Ruby** — keyword arguments, `Struct`-based value objects, block-based callbacks
- **Thread-safe** — uses a `Mutex` internally, safe for use with Puma and Sidekiq
- **Retry with exponential backoff** — configurable attempts, base delay, ceiling, and jitter
- **Circuit breaker** — opens after 5 consecutive failures, probes after 30 s
- **HMAC-SHA256 signing** — optional request signing for additional integrity verification
- **Key rotation** — primary + secondary API key with seamless failover
- **Rate limit callbacks** — pass a block to `Client.new` for rate-limit change notifications
- **PII detection** — warns when template variables contain sensitive field patterns
- **Error sanitization** — redacts file paths, IPs, keys, and emails from error messages

## Configuration Reference

| Option | Default | Description |
|--------|---------|-------------|
| `api_key` | — | **Required.** Must have prefix `sdk_`, `srv_`, or `cli_` |
| `base_url` | `https://api.huefy.dev/api/v1/sdk` | Override the API base URL |
| `timeout` | `30.0` | Request timeout in seconds |
| `retry_config.max_attempts` | `3` | Total attempts including the first |
| `retry_config.base_delay` | `0.5` | Exponential backoff base delay (seconds) |
| `retry_config.max_delay` | `10.0` | Maximum backoff delay (seconds) |
| `retry_config.jitter` | `0.2` | Random jitter factor (0–1) |
| `circuit_breaker_config.failure_threshold` | `5` | Consecutive failures before circuit opens |
| `circuit_breaker_config.reset_timeout` | `30.0` | Seconds before half-open probe |
| `logger` | `nil` | Standard Ruby `Logger` instance |
| `secondary_api_key` | `nil` | Backup key used during key rotation |
| `enable_request_signing` | `false` | Enable HMAC-SHA256 request signing |

### Rate Limit Callback

```ruby
client = Teracrafts::Huefy::EmailClient.new(
  api_key: 'sdk_your_api_key'
) do |info|
  puts "Rate limit: #{info.remaining}/#{info.limit}, resets at #{info.reset_at}"
end
```

## Bulk Email

```ruby
results = client.send_bulk_emails(
  template_key: 'promo',
  recipients: [
    Teracrafts::Huefy::Models::BulkRecipient.new(email: 'bob@example.com'),
    Teracrafts::Huefy::Models::BulkRecipient.new(email: 'carol@example.com'),
  ]
)

puts "Sent: #{results.data.success_count}, Failed: #{results.data.failure_count}"
```

## Error Handling

```ruby
require "teracrafts/huefy"

begin
  response = client.send_email(
    template_key: 'order-confirmation',
    recipient: 'user@example.com',
    data: {}
  )
  puts "Delivered: #{response.data.email_id}"
rescue Teracrafts::Huefy::HuefyError => e
  if [Teracrafts::Huefy::ErrorCodes::AUTH_INVALID_KEY, Teracrafts::Huefy::ErrorCodes::AUTH_MISSING_KEY, Teracrafts::Huefy::ErrorCodes::AUTH_UNAUTHORIZED].include?(e.code)
    puts 'Invalid API key'
  elsif e.code == Teracrafts::Huefy::ErrorCodes::NETWORK_RETRY_LIMIT
    puts "Rate limited. Retry after #{e.retry_after}s"
  elsif e.code == Teracrafts::Huefy::ErrorCodes::CIRCUIT_OPEN
    puts 'Circuit open — service unavailable, backing off'
  elsif e.recoverable?
    puts "Network error: #{e.message}"
  else
    puts "Huefy error [#{e.code}]: #{e.message}"
  end
rescue StandardError => e
  puts "Unexpected error: #{e.message}"
end
```

### Error Code Reference

| Class | Code | Meaning |
|-------|------|---------|
| `Teracrafts::Huefy::HuefyError` | `AUTH_INVALID_KEY` / `AUTH_MISSING_KEY` / `AUTH_UNAUTHORIZED` | API key rejected |
| `Teracrafts::Huefy::HuefyError` | `NETWORK_RETRY_LIMIT` | Rate limit exceeded |
| `Teracrafts::Huefy::HuefyError` | `CIRCUIT_OPEN` | Circuit breaker tripped |
| `Teracrafts::Huefy::HuefyError` | `NETWORK_*`, `VALIDATION_ERROR`, `SECURITY_*` | Transport, validation, or security failure |

## Health Check

```ruby
health = client.health_check
unless health.healthy?
  warn "Huefy degraded: #{health.status}"
end
```

## Local Development

`HUEFY_MODE=local` resolves to `https://api.huefy.on/api/v1/sdk`. To bypass Caddy and hit the raw app port directly, override `base_url` to `http://localhost:8080/api/v1/sdk`:

```ruby
client = Teracrafts::Huefy::EmailClient.new(
  api_key: 'sdk_local_key',
  base_url: 'https://api.huefy.on/api/v1/sdk'
)
```

## Module Compatibility

The canonical Ruby module is `Teracrafts::Huefy`. Existing `Huefy::...` references remain available as a compatibility alias.

## Developer Guide

Full documentation, advanced patterns, and provider configuration are in the [Ruby Developer Guide](../../docs/spec/guides/ruby.guide.md).

## License

MIT

# huefy-ruby

Official Ruby SDK for [Huefy](https://huefy.dev) — transactional email delivery made simple.

## Installation

```bash
gem install huefy-ruby
```

Or add to your `Gemfile`:

```ruby
gem 'huefy-ruby', '~> 1.0'
```

Then:

```bash
bundle install
```

## Requirements

- Ruby 3.1+

## Quick Start

```ruby
require 'huefy'

client = Huefy::Client.new(
  config: Huefy::Config.new(api_key: 'sdk_your_api_key')
)

response = client.send_email(
  template_key: 'welcome-email',
  recipient: { email: 'alice@example.com', name: 'Alice' },
  variables: { first_name: 'Alice', trial_days: 14 }
)

puts "Message ID: #{response.message_id}"
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
client = Huefy::Client.new(
  config: Huefy::Config.new(api_key: 'sdk_your_api_key')
) do |info|
  puts "Rate limit: #{info.remaining}/#{info.limit}, resets at #{info.reset}"
end
```

## Bulk Email

```ruby
results = client.send_bulk_emails(
  emails: [
    { template_key: 'promo', recipient: { email: 'bob@example.com' } },
    { template_key: 'promo', recipient: { email: 'carol@example.com' } },
  ]
)

puts "Sent: #{results.total_sent}, Failed: #{results.total_failed}"
```

## Error Handling

```ruby
require 'huefy'

begin
  response = client.send_email(
    template_key: 'order-confirmation',
    recipient: { email: 'user@example.com' }
  )
  puts "Delivered: #{response.message_id}"
rescue Huefy::AuthError
  puts 'Invalid API key'
rescue Huefy::RateLimitError => e
  puts "Rate limited. Retry after #{e.retry_after}s"
rescue Huefy::CircuitOpenError
  puts 'Circuit open — service unavailable, backing off'
rescue Huefy::NetworkError => e
  puts "Network error: #{e.message}"
rescue Huefy::Error => e
  puts "Huefy error [#{e.code}]: #{e.message}"
end
```

### Error Code Reference

| Class | Code | Meaning |
|-------|------|---------|
| `Huefy::InitError` | 1001 | Client failed to initialise |
| `Huefy::AuthError` | 1102 | API key rejected |
| `Huefy::NetworkError` | 1201 | Upstream request failed |
| `Huefy::CircuitOpenError` | 1301 | Circuit breaker tripped |
| `Huefy::RateLimitError` | 2003 | Rate limit exceeded |
| `Huefy::TemplateMissingError` | 2005 | Template key not found |

## Health Check

```ruby
health = client.health_check
unless health.status == 'healthy'
  warn "Huefy degraded: #{health.status}"
end
```

## Local Development

Set `HUEFY_MODE=local` to point the SDK at a local Huefy server, or override `base_url` in config:

```ruby
client = Huefy::Client.new(
  config: Huefy::Config.new(
    api_key: 'sdk_local_key',
    base_url: 'http://localhost:3000/api/v1/sdk'
  )
)
```

## Developer Guide

Full documentation, advanced patterns, and provider configuration are in the [Ruby Developer Guide](../../docs/spec/guides/ruby.guide.md).

## License

MIT

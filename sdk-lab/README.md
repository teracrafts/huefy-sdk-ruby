# Huefy Ruby SDK Lab

Verifies the core email contract through the real `Teracrafts::Huefy::EmailClient` without sending live email.

## Run

```bash
./sdk-lab/run.sh
```

from `sdks/ruby/`.

## Scenarios

1. Initialization
2. Single email contract
3. Bulk email contract
4. Validation rejects invalid single recipient
5. Validation rejects invalid bulk request
6. Health check path
7. Cleanup

## Notes

- The lab swaps in a local stub HTTP client.
- It verifies request normalization, parsed responses, and validation-before-transport behavior.
- The launcher prefers a Homebrew Ruby toolchain when available and falls back to `bundle exec ruby` or `ruby`.

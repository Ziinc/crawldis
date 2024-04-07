# Crawldis

Delarative crawler. Deploy and remote control spiders. Fully self-hostable.

### Features

1. Selectors
   - CSS selectors
   - XPath selectors
2. Rate limiting
3. 3rd Party Scraping Services Integration
4. JSON schema validation for scraped data
5. HTTP/gRPC API for remote control
6. Multiple output destinations:
   - Flatfile: CSV, TSV, JSONL
   - Webhooks

## Development

```bash
# start containers
make start

# get an iex shell
make iex.{req|pro}

# web
mix phx.server
```

### 
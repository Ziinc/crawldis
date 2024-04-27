# Crawldis

![](https://img.shields.io/docker/pulls/ziinc/crawldis?label=ziinc%2Fcrawldis&link=https%3A%2F%2Fhub.docker.com%2Fr%2Fziinc%2Fcrawldis)

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

### Usage

1. Add config file, `init.json`

```json
{
  "max_request_concurrency": 1,
  "max_request_rate_per_sec": 1,
  "plugins": [["ExportJsonl", { "dir": "tmp" }]],
  "crawl_jobs": [
    {
      "start_urls": ["https://www.tzeyiing.com/posts"],
      "extract": {
        "posts": {
          "title": "css:nav ul li a",
          "url": "xpath://*/nav//ul/li/a/@href"
        }
      }
    }
  ]
}
```

2. Create a docker-compose file

```bash
version: "3.9"
services:
  worker:
    image: ziinc/crawldis:latest
    environment:
      CRAWLDIS_CONFIG_FILE: init.json
    volumes:
      - ./init.json:/app/rel/init.json
```

## Documentation

### Crawl Jobs

#### Extraction

XPath, CSS, and Regex selectors are supported.

##### Selector Chaining

Selectors can be chained using the `|>` "pipe right" operator, where each selector will select based on the previously selected nodes. All selectors can be mixed together.

- `css: ul li |> xpath: /div[@data-val]`
  - This will take all `<li>` nodes, and then iterate over them and extract out the inner text of all `<div data-val="...">` nodes.
- `xpath: //h1 |> regex:My name is .+$`
  - This will take all `<h1>` nodes and perform a regex scan over the inner text, extracting out all matching text, such as "My name is Bob".
- `xpath: //h1 |> regex:My name is (.+)$`
  - This will take all `<h1>` nodes and perform a regex scan over the inner text, extracting out all matching text groups only , such as "Bob".
- `regex: Last updated at\: (.+)$`
  - Extracts out the response body and performs a regex scan over it, retrieving all matching groups that have the same pattern, such as "15 July 2012".

There is no limit on the number of selectors that can be chained.

##### Attribute Extraction

Attribute extraction is supported for both CSS and XPath:

- `css: ul nav::attr('href')`
- `xpath: //ul/nav/@href`

### Configuration
Configuration can be at either the global level or the job level. Job level will take precedence over the global level and will override any provided setting.

#### Environment Variables

- `CRAWLDIS_CONFIG_FILE`: (string) path to configuration json file.

## Development

```bash
# build and publish containers
make docker.build
make docker.publish

# hardcoded version from mix.exs
make version

# setup env
mix setup

# start app
iex -S mix
```

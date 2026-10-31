# Docan Playbooks Documentation

Playbooks are user-created YAML files that extend Docan's capabilities by enabling custom API integrations, webhooks, and data transformations. They allow the AI to interact with external services on your behalf.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Playbook Structure](#playbook-structure)
3. [Configuration](#configuration)
4. [Triggers](#triggers)
5. [Actions](#actions)
6. [Step Types](#step-types)
7. [Variables & Templates](#variables--templates)
8. [Examples](#examples)
9. [Chat Workflow Patterns](#chat-workflow-patterns)
10. [Best Practices](#best-practices)
11. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Creating Your First Playbook

1. Open Docan and navigate to **Playbooks**
2. Click **New Playbook** or **Import**
3. Write your YAML configuration (see structure below)
4. Save and configure any required settings
5. Enable the playbook to start using it

### Minimal Example

```yaml
name: Hello World
version: 1.0.0
description: A simple greeting playbook
playbookVersion: 1

triggers:
  - pattern: "hello|greet"

actions:
  greet:
    description: Say hello
    parameters:
      name:
        type: string
        required: true
    steps:
      - type: returnData
        data:
          message: "Hello, {{params.name}}!"
```

---

## Playbook Structure

Every playbook YAML file has the following structure:

```yaml
# Required fields
name: String           # Display name
version: String        # Semantic version (e.g., "1.0.0")
playbookVersion: Int   # SDK version (currently 1)

# Optional metadata
description: String    # What the playbook does
author: String         # Creator name
repository: String     # Git repository URL
license: String        # License type (MIT, Apache, etc.)
icon: String           # Icon identifier

# Platform support (optional, defaults to all)
platforms:
  - android
  - ios
  - linux
  - macos
  - windows
  - web

# Configuration (optional)
config:
  fieldName:
    type: string|number|boolean|select|multiselect
    required: boolean
    description: String
    secret: boolean
    default: any
    options: [...]  # For select/multiselect

# Triggers (optional but recommended)
triggers:
  - pattern: String    # Regex pattern
    description: String
    priority: Int      # Higher = checked first

# Actions (required)
actions:
  actionName:
    description: String
    parameters:
      paramName:
        type: string|number|boolean|array|object
        required: boolean
        description: String
        default: any
    steps:
      - type: stepType
        # ... step configuration
        # Optional error handling:
        retries: Int         # Number of retry attempts (default: 0)
        retryDelay: Int      # Delay between retries in ms (default: 1000)
        onFailure: String    # 'throw' | 'continue' | 'returnError'
    returns:
      type: String
      description: String
```

---

## Configuration

Configuration fields define settings that users must provide before using the playbook (like API keys).

### Field Types

| Type | Description | Example |
|------|-------------|---------|
| `string` | Text input | API keys, usernames |
| `number` | Numeric input | Limits, timeouts |
| `boolean` | True/false toggle | Feature flags |
| `select` | Single choice dropdown | Units, modes |
| `multiselect` | Multiple choice | Platforms, categories |

### Example

```yaml
config:
  apiKey:
    type: string
    required: true
    description: Your API key
    secret: true      # Hides input

  maxResults:
    type: number
    required: false
    default: 10
    description: Maximum results to return

  units:
    type: select
    default: metric
    options:
      - metric
      - imperial
```

### Accessing Config Values

Use `{{config.fieldName}}` in your steps:

```yaml
steps:
  - type: http
    url: "https://api.example.com/data"
    params:
      key: "{{config.apiKey}}"
```

---

## Triggers

Triggers determine when the AI should consider using your playbook. They use regex patterns to match user queries.

```yaml
triggers:
  - pattern: "youtube|video|channel"
    description: YouTube related queries
    priority: 10

  - pattern: "latest video|newest upload"
    description: Recent video queries
    priority: 5
```

### Priority

- Higher priority triggers are checked first
- Use higher priority for more specific patterns
- Default priority is 0

### Pattern Tips

- Use `|` for alternatives: `"weather|forecast|temperature"`
- Use `.*` for wildcards: `"search.*youtube"`
- Patterns are case-insensitive

---

## Actions

Actions are the operations your playbook can perform. Each action has:

- **name**: Unique identifier (the key in the YAML)
- **description**: What the action does
- **parameters**: Input data the action needs
- **steps**: Sequence of operations to execute
- **returns**: Description of output format

```yaml
actions:
  searchVideos:
    description: Search for videos on YouTube
    parameters:
      query:
        type: string
        required: true
        description: Search query
      maxResults:
        type: number
        default: 10
    steps:
      - type: http
        # ... steps
    returns:
      type: array
      description: List of video objects
```

---

## Step Types

### HTTP Request (`http`)

Make HTTP API calls.

```yaml
- type: http
  method: GET|POST|PUT|PATCH|DELETE
  url: "https://api.example.com/endpoint"
  headers:
    Authorization: "Bearer {{config.apiKey}}"
    Content-Type: application/json
  params:                    # Query parameters (for GET)
    q: "{{params.query}}"
  body:                      # Request body (for POST/PUT/PATCH)
    data: "{{params.data}}"
  timeout: 30000             # Request timeout in ms (default: 30000)
  response:
    store: variableName      # Store response in variable
  # Error handling (optional)
  retries: 3                 # Retry up to 3 times on failure
  retryDelay: 2000           # Wait 2 seconds between retries
  onFailure: continue        # 'throw' (default), 'continue', or 'returnError'
```

#### Error Handling Options

| Option | Description |
|--------|-------------|
| `throw` | Stop execution and return error (default) |
| `continue` | Log error and continue to next step |
| `returnError` | Stop execution and return error data |

### Webhook (`webhook`)

Send data to a webhook URL.

```yaml
- type: webhook
  url: "https://webhook.example.com/notify"
  payload:
    event: "action_completed"
    data: "{{result}}"
```

### Transform (`transform`)

Transform arrays or objects.

```yaml
- type: transform
  input: "{{apiResponse.items}}"
  output: processedItems
  filter: "{{item.active}} == true"  # Optional
  map:
    id: "{{item.id}}"
    name: "{{item.title}}"
    url: "https://example.com/{{item.id}}"
```

### Condition (`condition`)

Execute steps conditionally.

```yaml
- type: condition
  if: "{{results.length}} > 0"
  then:
    - type: returnData
      data: "{{results}}"
  else:
    - type: returnData
      data:
        error: "No results found"
```

### Loop (`loop`)

Iterate over arrays.

```yaml
- type: loop
  items: "{{data.list}}"
  as: item
  steps:
    - type: http
      url: "https://api.example.com/{{item.id}}"
      response:
        store: "details_{{index}}"
```

### Set Variable (`setVariable`)

Store a value in a variable.

```yaml
- type: setVariable
  name: greeting
  value: "Hello, {{params.name}}!"
```

### Return Data (`returnData`)

Return data to the AI (usually the last step).

```yaml
- type: returnData
  data:
    success: true
    results: "{{processedData}}"
  message: "Found {{results.length}} items"  # Optional
```

### Ask User (`askUser`)

Request additional input from the user.

> **Placeholder:** not yet wired to the chat UI — steps of this type currently fail with "requires UI integration".

```yaml
- type: askUser
  question: "Which channel do you mean?"
  options:
    - "Channel A"
    - "Channel B"
    - "Channel C"
```

### Ask AI (`askAI`)

Request the AI to process data.

> **Placeholder:** not yet wired to the AI service — steps of this type currently fail with "requires AI service integration".

```yaml
- type: askAI
  prompt: "Summarize these search results"
  data: "{{searchResults}}"
```

---

## Variables & Templates

### Template Syntax

Use `{{expression}}` for variable substitution:

```yaml
url: "https://api.example.com/users/{{params.userId}}"
message: "Found {{results.length}} items"
```

### Available Variables

| Variable | Description |
|----------|-------------|
| `{{config.*}}` | User configuration values |
| `{{params.*}}` | Action parameters |
| `{{variableName}}` | Variables from previous steps |
| `{{item}}` | Current item in loops/transforms |
| `{{index}}` | Current index in loops |

### Path Access

Access nested properties with dot notation:

```yaml
title: "{{response.data.items[0].snippet.title}}"
count: "{{results.length}}"
```

### Array Access

```yaml
firstItem: "{{items[0]}}"
lastItem: "{{items[-1]}}"
```

---

## Examples

### Simple API Call

```yaml
name: IP Info
version: 1.0.0
playbookVersion: 1

triggers:
  - pattern: "ip|location|where am i"

actions:
  getMyIP:
    description: Get current IP address and location
    steps:
      - type: http
        method: GET
        url: "https://ipapi.co/json/"
        response:
          store: ipData
      - type: returnData
        data:
          ip: "{{ipData.ip}}"
          city: "{{ipData.city}}"
          country: "{{ipData.country_name}}"
```

### With Authentication

```yaml
name: GitHub
version: 1.0.0
playbookVersion: 1

config:
  token:
    type: string
    required: true
    secret: true
    description: GitHub Personal Access Token

actions:
  getRepos:
    description: List your repositories
    steps:
      - type: http
        method: GET
        url: "https://api.github.com/user/repos"
        headers:
          Authorization: "Bearer {{config.token}}"
          Accept: application/vnd.github.v3+json
        response:
          store: repos
      - type: transform
        input: "{{repos}}"
        output: repoList
        map:
          name: "{{item.name}}"
          url: "{{item.html_url}}"
          stars: "{{item.stargazers_count}}"
      - type: returnData
        data:
          count: "{{repoList.length}}"
          repositories: "{{repoList}}"
```

### Multi-Step with Conditions

```yaml
actions:
  findAndGetDetails:
    description: Search and get details
    parameters:
      query:
        type: string
        required: true
    steps:
      # Step 1: Search
      - type: http
        method: GET
        url: "https://api.example.com/search"
        params:
          q: "{{params.query}}"
        response:
          store: searchResults

      # Step 2: Check if results exist
      - type: condition
        if: "{{searchResults.items.length}} == 0"
        then:
          - type: returnData
            data:
              success: false
              message: "No results found"

      # Step 3: Get details for first result
      - type: http
        method: GET
        url: "https://api.example.com/items/{{searchResults.items[0].id}}"
        response:
          store: details

      # Step 4: Return combined data
      - type: returnData
        data:
          success: true
          query: "{{params.query}}"
          result: "{{details}}"
```

---

## Chat Workflow Patterns

These are complete, ready-to-import playbooks illustrating common chat workflow patterns. Import one, adjust the config and URLs for your own services, and chat naturally — the trigger matches your message, the AI extracts the parameters, the playbook fetches live data, and the AI interprets the result in its reply.

> **Note:** The `askUser` and `askAI` step types are placeholders in the current executor and will fail if used. The patterns below use only working step types.

### Pattern 1: Live Public Lookup (no authentication)

Free public APIs need no key — the chat becomes a live data source. Ask naturally; the AI extracts the location and day count from your sentence.

*"Will it rain in York this weekend?"*

```yaml
name: Weather
version: 1.0.0
playbookVersion: 1
description: Current weather and forecast for any location (Open-Meteo, no API key)

triggers:
  - pattern: "weather|forecast|rain|temperature"
    priority: 5

actions:
  getWeather:
    description: Get the forecast for a location
    parameters:
      location:
        type: string
        required: true
        description: City or town name, e.g. "York"
      days:
        type: number
        default: 3
        description: How many days of forecast to include
    steps:
      - type: http
        method: GET
        url: "https://geocoding-api.open-meteo.com/v1/search"
        params:
          name: "{{params.location}}"
          count: "1"
        response:
          store: geo
      - type: condition
        if: "{{geo.results.length}} > 0"
        then:
          - type: setVariable
            name: lat
            value: "{{geo.results[0].latitude}}"
          - type: setVariable
            name: lon
            value: "{{geo.results[0].longitude}}"
          - type: http
            method: GET
            url: "https://api.open-meteo.com/v1/forecast?latitude={{lat}}&longitude={{lon}}&daily=temperature_2m_max,temperature_2m_min,precipitation_sum&forecast_days={{params.days}}"
            response:
              store: forecast
          - type: returnData
            data:
              location: "{{geo.results[0].name}}, {{geo.results[0].country}}"
              daily: "{{forecast.daily}}"
        else:
          - type: returnData
            data:
              success: false
              message: "Could not find a location called {{params.location}}"
```

The AI receives the daily arrays and renders them as a markdown table in the chat.

### Pattern 2: Authenticated Personal Data (secret config)

Your own data behind a token. The key is marked `secret: true` so it is stored in encrypted secure storage.

*"What PRs have I got waiting for review, oldest first?"*

```yaml
name: GitHub PR Queue
version: 1.0.0
playbookVersion: 1
description: List your open pull requests oldest-first

config:
  token:
    type: string
    required: true
    secret: true
    description: GitHub personal access token

triggers:
  - pattern: "open (prs|pull requests)|pr queue|waiting for review"
    priority: 5

actions:
  listOpenPRs:
    description: List your open pull requests
    steps:
      - type: http
        method: GET
        url: "https://api.github.com/search/issues?q=is:pr+state:open+author:@me&sort=created&order=asc&per_page=20"
        headers:
          Authorization: "Bearer {{config.token}}"
          Accept: "application/vnd.github+json"
        response:
          store: search
      - type: transform
        input: "{{search.items}}"
        output: prs
        map:
          title: "{{item.title}}"
          repo: "{{item.repository_url}}"
          created: "{{item.created_at}}"
          url: "{{item.html_url}}"
      - type: returnData
        data:
          count: "{{prs.length}}"
          pull_requests: "{{prs}}"
```

The AI works out the ages from the `created` dates and ranks them in its reply.

### Pattern 3: Monitoring Sweep (loop over a list)

Fan out over a configured list of endpoints; the AI turns the results into a status table and flags anything that failed to respond.

*"Check all my services and flag anything down."*

```yaml
name: Service Health
version: 1.0.0
playbookVersion: 1
description: Check a list of service health endpoints and report the results

config:
  services:
    type: multiselect
    required: true
    description: Health endpoints to check (edit the options for your services)
    options:
      - "https://service-one.example.com/health"
      - "https://service-two.example.com/health"

triggers:
  - pattern: "check.*services|service health|anything down"
    priority: 5

actions:
  checkServices:
    description: Check each configured service
    steps:
      - type: loop
        items: "{{config.services}}"
        as: url
        output: checks
        steps:
          - type: http
            method: GET
            url: "{{url}}"
            timeout: 5000
            onFailure: continue
            response:
              store: checkResponse
          - type: returnData
            data:
              url: "{{url}}"
              status: "{{checkResponse.status}}"
      - type: returnData
        data:
          results: "{{checks}}"
```

A failed request leaves `status` empty for that entry — the AI sees the gap and flags the service as unreachable. Adjust the `options` list and the status field to match your own health endpoints.

### Pattern 4: Write Action (webhook)

Playbooks are not read-only — a webhook step lets the chat drive external systems.

*"Remind me to check the kiln at 6pm."*

```yaml
name: Notify Me
version: 1.0.0
playbookVersion: 1
description: Send a notification to a webhook (Home Assistant, IFTTT, ntfy, etc.)

config:
  webhookUrl:
    type: string
    required: true
    secret: true
    description: Webhook URL to POST notifications to

triggers:
  - pattern: "notify|remind me|alert me"
    priority: 5

actions:
  sendNotification:
    description: Send a notification message
    parameters:
      message:
        type: string
        required: true
        description: The notification text
    steps:
      - type: webhook
        url: "{{config.webhookUrl}}"
        payload:
          text: "{{params.message}}"
          source: "Docan chat"
      - type: returnData
        data:
          sent: true
          message: "{{params.message}}"
```

### Pattern 5: Domain Data (your own business systems)

The same shape works for any REST API you run. This one queries ERPNext (Frappe token auth) — the AI renders the invoice list and totals it.

*"How many unpaid sales invoices over 1000 do we have?"*

```yaml
name: ERPNext Invoices
version: 1.0.0
playbookVersion: 1
description: Query outstanding sales invoices from an ERPNext site

config:
  siteUrl:
    type: string
    required: true
    description: Your ERPNext site, e.g. https://erp.example.com
  apiKey:
    type: string
    required: true
    secret: true
    description: Frappe API key
  apiSecret:
    type: string
    required: true
    secret: true
    description: Frappe API secret

triggers:
  - pattern: "invoice|outstanding|receivable"
    priority: 5

actions:
  outstandingInvoices:
    description: List unpaid sales invoices above an amount
    parameters:
      minAmount:
        type: number
        default: 1000
        description: Only include invoices with a grand total above this
    steps:
      - type: http
        method: GET
        url: "{{config.siteUrl}}/api/resource/Sales%20Invoice"
        headers:
          Authorization: "token {{config.apiKey}}:{{config.apiSecret}}"
        params:
          fields: '["name","customer","grand_total","due_date","status"]'
          filters: '[["status","=","Unpaid"],["grand_total",">",{{params.minAmount}}]]'
          limit_page_length: "50"
        response:
          store: invoices
      - type: transform
        input: "{{invoices.data}}"
        output: rows
        map:
          invoice: "{{item.name}}"
          customer: "{{item.customer}}"
          total: "{{item.grand_total}}"
          due: "{{item.due_date}}"
      - type: returnData
        data:
          count: "{{rows.length}}"
          invoices: "{{rows}}"
```

### Adapting a Pattern

1. **Import** the YAML into Playbooks and enable it
2. **Fill the config** (keys marked `secret: true` go into secure storage)
3. **Chat naturally** — or invoke directly with `/playbook <name> <request>`
4. **Modify** for your own API: the trigger patterns should match how you naturally ask; the parameter descriptions are the instructions the AI uses to extract values from your sentence; `returnData` shapes what the AI has to interpret

---

## Best Practices

### 1. Use Descriptive Names

```yaml
# Good
actions:
  searchChannelsByName:
    description: Search for YouTube channels by their name or keywords

# Avoid
actions:
  action1:
    description: does stuff
```

### 2. Handle Errors Gracefully

Use step-level error handling:

```yaml
steps:
  - type: http
    url: "{{apiUrl}}"
    retries: 3              # Retry on transient failures
    retryDelay: 1000        # 1 second between retries
    onFailure: continue     # Don't stop on error
    response:
      store: result
  - type: condition
    if: "{{result.error}}"
    then:
      - type: returnData
        data:
          success: false
          error: "{{result.error.message}}"
```

Or use conditional checks:

```yaml
steps:
  - type: http
    url: "{{apiUrl}}"
    response:
      store: result
  - type: condition
    if: "{{result.error}}"
    then:
      - type: returnData
        data:
          success: false
          error: "{{result.error.message}}"
```

### 3. Use Appropriate Triggers

```yaml
triggers:
  # More specific patterns with higher priority
  - pattern: "latest.*youtube.*video"
    priority: 10
  # Broader patterns with lower priority
  - pattern: "youtube|video"
    priority: 1
```

### 4. Document Your Playbook

```yaml
description: |
  This playbook integrates with the Weather API.
  
  Features:
  - Current weather
  - 5-day forecast
  - Air quality index
  
  Requirements:
  - OpenWeatherMap API key (free tier works)
```

### 5. Keep Secrets Secure

```yaml
config:
  apiKey:
    type: string
    required: true
    secret: true  # Always mark sensitive data
```

> **Note**: Fields marked with `secret: true` are stored in encrypted secure storage, not plain SharedPreferences.

---

## Troubleshooting

### Common Issues

**Playbook not triggering**
- Check your trigger patterns with a regex tester
- Ensure the playbook is enabled
- Verify all required config is provided

**HTTP requests failing**
- Check the API URL is correct
- Verify authentication headers
- Test the API directly with curl/Postman

**Variables not resolving**
- Ensure the variable is stored before use
- Check path syntax (dots vs brackets)
- Verify the API response structure

### Debug Tips

1. Start with simple actions and add complexity
2. Test each step individually
3. Check the playbook detail view for configuration status
4. Export and re-import if making manual edits

---

## SDK Version History

### Version 1.1 (Current)

- **Retry logic**: `retries` and `retryDelay` options per step
- **Failure strategies**: `onFailure` option (`throw`, `continue`, `returnError`)
- **Secure storage**: Secret config values stored in encrypted secure storage
- **HTTP timeout**: Configurable `timeout` for HTTP requests
- **Fuzzy matching**: Improved trigger pattern matching with word similarity
- **Progress streaming**: Real-time execution status updates
- **Dry run**: Validate playbook before execution

### Version 1.0

- Initial release
- Step types: http, webhook, transform, condition, loop, setVariable, returnData, askUser, askAI
- Template syntax with `{{}}`
- Config field types: string, number, boolean, select, multiselect

---

## Getting Help

- Check the example playbooks in the app
- Visit the GitHub repository for more examples
- Open an issue for bugs or feature requests

Happy building! 🚀

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
9. [Best Practices](#best-practices)
10. [Troubleshooting](#troubleshooting)

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

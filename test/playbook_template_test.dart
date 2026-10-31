import 'package:flutter_test/flutter_test.dart';
import 'package:docan/models/playbook.dart';

const templateYaml = '''
name: My Playbook
version: 1.0.0
description: A custom playbook for Docan
author: Your Name
playbookVersion: 1

platforms:
  - android
  - ios
  - linux
  - macos
  - windows
  - web

config:
  apiKey:
    type: string
    required: true
    description: API key for the service
    secret: true

triggers:
  - pattern: "my trigger|keyword"
    description: When to activate this playbook
    priority: 0

actions:
  myAction:
    description: Does something useful
    parameters:
      query:
        type: string
        required: true
        description: The search query
    steps:
      - type: http
        method: GET
        url: "https://api.example.com/search"
        params:
          q: "{{params.query}}"
          key: "{{config.apiKey}}"
        response:
          store: searchResults
      - type: returnData
        data:
          results: "{{searchResults}}"
    returns:
      type: object
      description: Search results
''';

void main() {
  test('the New Playbook template parses as a valid playbook', () {
    final playbook = Playbook.fromYaml(templateYaml);
    expect(playbook.name, 'My Playbook');
    expect(playbook.actions, isNotEmpty);
    expect(playbook.config, isNotEmpty);
    expect(playbook.triggers, isNotEmpty);
  });
}

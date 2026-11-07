// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'dart:async';

const Symbol _suppressKey = #dartastic_otel_libs_webhook_suppress;

/// Whether instrumentation is suppressed in the current zone.
bool webhookInstrumentationSuppressed() {
  return Zone.current[_suppressKey] == true;
}

/// Runs [body] without creating spans for calls made inside it.
T runWithoutWebhookInstrumentation<T>(T Function() body) {
  return runZoned(body, zoneValues: {_suppressKey: true});
}

/// Runs [body] without creating spans for calls made inside it.
Future<T> runWithoutWebhookInstrumentationAsync<T>(
  Future<T> Function() body,
) {
  return runZoned(body, zoneValues: {_suppressKey: true});
}

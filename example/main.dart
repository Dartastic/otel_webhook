// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_webhook/otel_webhook.dart';

/// Traces Webhook calls with OpenTelemetry.
///
/// `otel_webhook` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Webhook call in
/// [tracedWebhookPost]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'webhook-example');

  // Wraps a generic outbound webhook POST in a PRODUCER span.
  final webhookPostId = await tracedWebhookPost<String>(
    url: 'https://api.example.com/v1/resource',
    destinationName: 'example',
    payloadSize: 512,
    eventType: 'order.created',
    signatureAlgorithm: 'example',
    invoke: () async {
      // Make the Webhook call here, then report what it returned.
      const id = 'webhook_8f3a2c';
      return const WebhookPostResult(value: id, statusCode: 200, attempt: 1);
    },
  );
  OTelLog.info('tracedWebhookPost returned $webhookPostId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutWebhookInstrumentationAsync.
  await runWithoutWebhookInstrumentationAsync(
    () => tracedWebhookPost<String>(
      url: 'https://api.example.com/v1/resource',
      destinationName: 'example',
      payloadSize: 512,
      eventType: 'order.created',
      signatureAlgorithm: 'example',
      invoke: () async {
        const id = 'webhook_8f3a2c';
        return const WebhookPostResult(value: id, statusCode: 200, attempt: 1);
      },
    ),
  );

  await OTel.shutdown();
}

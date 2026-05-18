// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_webhook/otel_webhook.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_webhook-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('successful POST records PRODUCER span with host', () async {
    await tracedWebhookPost<String>(
      url: 'https://example.com/hooks/abc',
      payloadSize: 256,
      eventType: 'order.created',
      signatureAlgorithm: 'hmac-sha256',
      invoke: () async => const WebhookPostResult(
        value: 'ok',
        statusCode: 200,
        attempt: 1,
      ),
    );
    final span = spans.findSpanByName('webhook POST example.com');
    expect(span, isNotNull);
    expect(span!.kind, SpanKind.producer);
    final a = attrsOf(span);
    expect(a['messaging.system'], 'webhook');
    expect(a['messaging.destination.name'], 'example.com');
    expect(a['url.full'], 'https://example.com/hooks/abc');
    expect(a['http.request.method'], 'POST');
    expect(a['webhook.event.type'], 'order.created');
    expect(a['webhook.signature.algorithm'], 'hmac-sha256');
    expect(a['http.response.status_code'], 200);
    expect(a['webhook.attempt'], 1);
  });

  test('HTTP 500 marks span Error', () async {
    await tracedWebhookPost<String>(
      url: 'https://example.com/h',
      invoke: () async => const WebhookPostResult(
        value: 'fail',
        statusCode: 500,
      ),
    );
    expect(
      spans.findSpanByName('webhook POST example.com')!.status,
      SpanStatusCode.Error,
    );
  });

  test('suppression skips spans', () async {
    await runWithoutWebhookInstrumentationAsync(() async {
      await tracedWebhookPost<String>(
        url: 'https://x.com/h',
        invoke: () async => const WebhookPostResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('webhook '), isEmpty);
  });
}

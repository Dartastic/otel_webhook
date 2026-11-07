// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_webhook_suppression.dart';

const _tracerName = 'dartastic_otel_libs_webhook';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

/// Pair returned from `tracedWebhookPost` callback.
class WebhookPostResult<T> {
  /// Creates a result.
  const WebhookPostResult({
    required this.value,
    this.statusCode,
    this.attempt,
  });

  /// The value returned to the caller.
  final T value;
  final int? statusCode;
  final int? attempt;
}

/// Wraps a generic outbound webhook POST in a PRODUCER span. The
/// destination host (or webhook name) is recorded so traces can
/// be grouped by target. Marks span Error on HTTP >= 400.
Future<T> tracedWebhookPost<T>({
  required String url,
  required Future<WebhookPostResult<T>> Function() invoke,
  String? destinationName,
  int? payloadSize,
  String? eventType,
  String? signatureAlgorithm,
}) async {
  if (webhookInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final dest = destinationName ?? _hostFromUrl(url) ?? 'webhook';
  final m = <String, Object>{
    'messaging.system': 'webhook',
    'messaging.operation': 'publish',
    'messaging.destination.name': dest,
    'url.full': url,
    'http.request.method': 'POST',
  };
  if (payloadSize != null) m['messaging.message.body.size'] = payloadSize;
  if (eventType != null) m['webhook.event.type'] = eventType;
  if (signatureAlgorithm != null) {
    m['webhook.signature.algorithm'] = signatureAlgorithm;
  }

  final span = _tracer().startSpan(
    'webhook POST $dest',
    kind: SpanKind.producer,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    final extras = <Attribute<Object>>[];
    if (r.statusCode != null) {
      extras.add(
        OTelAPI.attributeInt('http.response.status_code', r.statusCode!),
      );
      if (r.statusCode! >= 400) {
        span.setStatus(SpanStatusCode.Error, 'HTTP ${r.statusCode}');
      }
    }
    if (r.attempt != null) {
      extras.add(OTelAPI.attributeInt('webhook.attempt', r.attempt!));
    }
    if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}

String? _hostFromUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return null;
  return uri.host;
}

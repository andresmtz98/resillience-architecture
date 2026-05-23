import {
  CloudWatchClient,
  PutMetricDataCommand,
} from "@aws-sdk/client-cloudwatch";

const NAMESPACE = process.env.METRIC_NAMESPACE!;
const client = new CloudWatchClient({});

interface Event {
  payload?: { message?: string; timestamp?: string; error?: boolean };
}

async function publishRequestServed(level: number): Promise<void> {
  try {
    await client.send(
      new PutMetricDataCommand({
        Namespace: NAMESPACE,
        MetricData: [
          {
            MetricName: "RequestsByLevel",
            Value: 1,
            Unit: "Count",
            Dimensions: [{ Name: "Level", Value: String(level) }],
            Timestamp: new Date(),
          },
        ],
      })
    );
  } catch {
    // Best-effort observability: don't fail the request if metrics fail.
  }
}

export async function handler(event: Event) {
  await publishRequestServed(1);
  return {
    level: 1,
    message: "Nivel 1: Sistema operando completamente",
    received: event.payload ?? null,
    processed_at: new Date().toISOString(),
  };
}

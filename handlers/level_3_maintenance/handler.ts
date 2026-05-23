import {
  CloudWatchClient,
  PutMetricDataCommand,
} from "@aws-sdk/client-cloudwatch";

const NAMESPACE = process.env.METRIC_NAMESPACE!;
const client = new CloudWatchClient({});

interface Event {
  payload?: { error?: boolean };
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
  await publishRequestServed(3);
  const isError = event.payload?.error === true;
  return {
    level: 3,
    message: isError
      ? "Nivel 3: Sistema bajo mantenimiento, intente más tarde"
      : "Nivel 3: Operación al mínimo",
    processed_at: new Date().toISOString(),
  };
}

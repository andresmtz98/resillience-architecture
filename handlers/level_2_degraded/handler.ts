import {
  CloudWatchClient,
  PutMetricDataCommand,
} from "@aws-sdk/client-cloudwatch";

const NAMESPACE = process.env.METRIC_NAMESPACE!;
const client = new CloudWatchClient({});

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

export async function handler() {
  await publishRequestServed(2);
  return {
    level: 2,
    message: "Nivel 2: Sistema degradado, solo funcionan los servicios críticos",
    processed_at: new Date().toISOString(),
  };
}

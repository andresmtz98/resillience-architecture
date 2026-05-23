import {
  CloudWatchClient,
  PutMetricDataCommand,
} from "@aws-sdk/client-cloudwatch";
import { ServiceLevel } from "../domain/types";

const NAMESPACE = process.env.METRIC_NAMESPACE!;
const client = new CloudWatchClient({});

export function log(message: string, data?: object): void {
  console.log(JSON.stringify({ timestamp: new Date().toISOString(), message, ...data }));
}

/**
 * Emits the current service level as a gauge. Should be called at the end of
 * every evaluation (transition or not) so CloudWatch graphs show a continuous
 * line rather than only points at transition times.
 */
export async function publishServiceLevel(level: ServiceLevel): Promise<void> {
  await client.send(
    new PutMetricDataCommand({
      Namespace: NAMESPACE,
      MetricData: [
        {
          MetricName: "ServiceLevel",
          Value: level,
          Unit: "None",
          Timestamp: new Date(),
        },
      ],
    })
  );
}

export async function publishLevelTransition(
  fromLevel: ServiceLevel,
  toLevel: ServiceLevel
): Promise<void> {
  await client.send(
    new PutMetricDataCommand({
      Namespace: NAMESPACE,
      MetricData: [
        {
          MetricName: "ServiceLevel",
          Value: toLevel,
          Unit: "None",
          Timestamp: new Date(),
        },
        {
          MetricName: "LevelTransition",
          Value: 1,
          Unit: "Count",
          Dimensions: [
            { Name: "From", Value: String(fromLevel) },
            { Name: "To", Value: String(toLevel) },
          ],
          Timestamp: new Date(),
        },
      ],
    })
  );
}

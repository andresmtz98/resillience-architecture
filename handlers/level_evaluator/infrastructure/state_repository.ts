import {
  DynamoDBClient,
  GetItemCommand,
  UpdateItemCommand,
} from "@aws-sdk/client-dynamodb";
import { ServiceLevel, SystemState } from "../domain/types";

const TABLE_NAME = process.env.STATE_TABLE_NAME!;
const ITEM_KEY = { id: { S: "system" } };

const client = new DynamoDBClient({});

export async function getState(): Promise<SystemState> {
  const res = await client.send(
    new GetItemCommand({ TableName: TABLE_NAME, Key: ITEM_KEY })
  );
  if (!res.Item) throw new Error("System state not initialized");

  return {
    level: Number(res.Item.level.N) as ServiceLevel,
    errorCountCurrentMinute: Number(res.Item.error_count_current_minute.N),
    currentMinuteStart: Number(res.Item.current_minute_start.N),
    errorsLastMinute: Number(res.Item.errors_last_minute.N),
    lastTransitionAt: Number(res.Item.last_transition_at.N),
    lastTransitionReason: res.Item.last_transition_reason.S ?? "init",
  };
}

/**
 * Rolls over the minute window: saves current count as errors_last_minute
 * and resets the current count. Idempotent via condition expression.
 */
export async function rolloverIfNeeded(
  expectedMinuteStart: number,
  newMinuteStart: number,
  currentCount: number
): Promise<boolean> {
  try {
    await client.send(
      new UpdateItemCommand({
        TableName: TABLE_NAME,
        Key: ITEM_KEY,
        UpdateExpression:
          "SET errors_last_minute = :prev, error_count_current_minute = :zero, current_minute_start = :ms",
        ConditionExpression: "current_minute_start = :expected",
        ExpressionAttributeValues: {
          ":prev": { N: String(currentCount) },
          ":zero": { N: "0" },
          ":ms": { N: String(newMinuteStart) },
          ":expected": { N: String(expectedMinuteStart) },
        },
      })
    );
    return true;
  } catch (err: any) {
    if (err.name === "ConditionalCheckFailedException") return false;
    throw err;
  }
}

export async function applyTransition(
  newLevel: ServiceLevel,
  reason: string,
  nowMs: number
): Promise<void> {
  await client.send(
    new UpdateItemCommand({
      TableName: TABLE_NAME,
      Key: ITEM_KEY,
      UpdateExpression:
        "SET #lvl = :level, last_transition_at = :ts, last_transition_reason = :reason",
      ExpressionAttributeNames: { "#lvl": "level" },
      ExpressionAttributeValues: {
        ":level": { N: String(newLevel) },
        ":ts": { N: String(nowMs) },
        ":reason": { S: reason },
      },
    })
  );
}

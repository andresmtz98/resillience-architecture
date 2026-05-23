import { evaluateLevel } from "./application/evaluate_level";
import { log } from "./infrastructure/observability";

export async function handler(): Promise<void> {
  try {
    await evaluateLevel();
  } catch (err) {
    log("Level evaluation failed", { error: (err as Error).message });
    throw err;
  }
}

import { ServiceLevel } from "./types";

/**
 * Threshold-based level resolution.
 * Maps the number of errors observed in the just-closed minute to the
 * target service level, independently of the current level.
 *
 *   errors >= 10  -> level 3
 *   errors >= 5   -> level 2
 *   errors < 5    -> level 1
 */
export function resolveTargetLevel(errors: number): ServiceLevel {
  if (errors >= 10) return 3;
  if (errors >= 5) return 2;
  return 1;
}

export type TransitionDirection = "degrade" | "recover";

export interface Transition {
  newLevel: ServiceLevel;
  direction: TransitionDirection;
  reason: string;
}

/**
 * Pure function: given current level and errors observed in the just-closed
 * minute, returns the next transition or null if the level should stay.
 *
 *   - Degradation can jump multiple levels (1 -> 3 directly if errors >= 10).
 *   - Recovery is gradual: only one level up per evaluation, even if the
 *     observed errors would map to a much lower target.
 */
export function evaluateTransition(
  currentLevel: ServiceLevel,
  errorsLastMinute: number
): Transition | null {
  const target = resolveTargetLevel(errorsLastMinute);
  if (target === currentLevel) return null;

  if (target > currentLevel) {
    // Degradation: jump directly to the target level
    return {
      newLevel: target,
      direction: "degrade",
      reason: `errors_${errorsLastMinute}_target_level_${target}`,
    };
  }

  // Recovery: step down only one level at a time
  const newLevel = (currentLevel - 1) as ServiceLevel;
  return {
    newLevel,
    direction: "recover",
    reason: `errors_${errorsLastMinute}_step_down_to_${newLevel}`,
  };
}

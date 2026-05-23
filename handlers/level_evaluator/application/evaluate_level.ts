import { evaluateTransition } from "../domain/transition";
import { getMinuteStart } from "../domain/time_window";
import {
  applyTransition,
  getState,
  rolloverIfNeeded,
} from "../infrastructure/state_repository";
import {
  log,
  publishLevelTransition,
  publishServiceLevel,
} from "../infrastructure/observability";

/**
 * Periodic evaluator: closes the previous minute window (rollover) and
 * decides whether the system should degrade, recover, or stay at its
 * current level based on errors observed during that closed minute.
 */
export async function evaluateLevel(): Promise<void> {
  const now = Date.now();
  const currentMinuteNow = getMinuteStart(now);

  const state = await getState();

  // Step 1: rollover the minute if it's stale. This moves
  // error_count_current_minute into errors_last_minute and resets the counter.
  if (state.currentMinuteStart < currentMinuteNow) {
    const rolled = await rolloverIfNeeded(
      state.currentMinuteStart,
      currentMinuteNow,
      state.errorCountCurrentMinute
    );
    if (rolled) {
      log("Minute rolled over", {
        previous_minute_start: state.currentMinuteStart,
        new_minute_start: currentMinuteNow,
        errors_last_minute: state.errorCountCurrentMinute,
      });
      state.errorsLastMinute = state.errorCountCurrentMinute;
      state.errorCountCurrentMinute = 0;
      state.currentMinuteStart = currentMinuteNow;
    }
  }

  // Step 2: evaluate the unified transition rule (degrade or recover)
  const transition = evaluateTransition(state.level, state.errorsLastMinute);
  if (!transition) {
    log("No transition applies", {
      level: state.level,
      errors_last_minute: state.errorsLastMinute,
    });
    // Emit current level as a gauge even when no transition occurs, so
    // CloudWatch dashboards show a continuous timeseries.
    await publishServiceLevel(state.level);
    return;
  }

  await applyTransition(transition.newLevel, transition.reason, now);
  log(`Level transition (${transition.direction})`, {
    from: state.level,
    to: transition.newLevel,
    reason: transition.reason,
    errors_last_minute: state.errorsLastMinute,
  });
  await publishLevelTransition(state.level, transition.newLevel);
}

export type ServiceLevel = 1 | 2 | 3;

export interface SystemState {
  level: ServiceLevel;
  errorCountCurrentMinute: number;
  currentMinuteStart: number;
  errorsLastMinute: number;
  lastTransitionAt: number;
  lastTransitionReason: string;
}

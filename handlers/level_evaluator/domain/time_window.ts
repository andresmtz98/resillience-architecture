export function getMinuteStart(epochMs: number): number {
  return Math.floor(epochMs / 60_000) * 60_000;
}

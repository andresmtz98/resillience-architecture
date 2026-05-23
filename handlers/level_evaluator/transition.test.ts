import { describe, it, expect } from "vitest";
import { evaluateTransition, resolveTargetLevel } from "./domain/transition";

describe("resolveTargetLevel", () => {
  it("maps < 5 errors to level 1", () => {
    expect(resolveTargetLevel(0)).toBe(1);
    expect(resolveTargetLevel(4)).toBe(1);
  });

  it("maps 5..9 errors to level 2", () => {
    expect(resolveTargetLevel(5)).toBe(2);
    expect(resolveTargetLevel(9)).toBe(2);
  });

  it("maps >= 10 errors to level 3", () => {
    expect(resolveTargetLevel(10)).toBe(3);
    expect(resolveTargetLevel(100)).toBe(3);
  });
});

describe("evaluateTransition", () => {
  it("returns null when target equals current level", () => {
    expect(evaluateTransition(1, 0)).toBeNull();
    expect(evaluateTransition(1, 4)).toBeNull();
    expect(evaluateTransition(2, 5)).toBeNull();
    expect(evaluateTransition(2, 9)).toBeNull();
    expect(evaluateTransition(3, 10)).toBeNull();
    expect(evaluateTransition(3, 100)).toBeNull();
  });

  it("degrades from level 1 to 2 at 5 errors", () => {
    const t = evaluateTransition(1, 5);
    expect(t?.newLevel).toBe(2);
    expect(t?.direction).toBe("degrade");
  });

  it("degrades directly from level 1 to 3 at 10+ errors", () => {
    const t = evaluateTransition(1, 15);
    expect(t?.newLevel).toBe(3);
    expect(t?.direction).toBe("degrade");
  });

  it("degrades from level 2 to 3 at 10+ errors", () => {
    const t = evaluateTransition(2, 10);
    expect(t?.newLevel).toBe(3);
    expect(t?.direction).toBe("degrade");
  });

  it("recovers from level 3 to 2 (gradual) even when errors map to level 1", () => {
    const t = evaluateTransition(3, 0);
    expect(t?.newLevel).toBe(2);
    expect(t?.direction).toBe("recover");
  });

  it("recovers from level 3 to 2 when errors are 5..9", () => {
    const t = evaluateTransition(3, 7);
    expect(t?.newLevel).toBe(2);
    expect(t?.direction).toBe("recover");
  });

  it("recovers from level 2 to 1 when errors < 5", () => {
    const t = evaluateTransition(2, 0);
    expect(t?.newLevel).toBe(1);
    expect(t?.direction).toBe("recover");
  });
});

describe("evaluateTransition - script trajectory walk-through", () => {
  // Test script (140 iterations / 6 minutes):
  //   min 1: 5 errors  -> level 2
  //   min 2: 0 errors  -> level 1 (recover step)
  //   min 3: 15 errors -> level 3 (jump)
  //   min 4: 0 errors  -> level 2 (recover step, gradual)
  //   min 5: 15 errors -> level 3 (jump)
  //   min 6: 0 errors  -> level 2 (recover step, gradual)
  //   (next eval)      -> level 1 (recover step, gradual)
  it("walks through the k6 script scenario with gradual recovery", () => {
    let level: 1 | 2 | 3 = 1;
    const steps: Array<{ errors: number; expected: 1 | 2 | 3 }> = [
      { errors: 5, expected: 2 },
      { errors: 0, expected: 1 },
      { errors: 15, expected: 3 },
      { errors: 0, expected: 2 },
      { errors: 15, expected: 3 },
      { errors: 0, expected: 2 },
      { errors: 0, expected: 1 },
    ];

    for (const step of steps) {
      const t = evaluateTransition(level, step.errors);
      if (t) level = t.newLevel;
      expect(level).toBe(step.expected);
    }
  });
});

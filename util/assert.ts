import assert from "node:assert";

export function assertNumber(a: number, b: number, msg?: string) {
  assert(Math.abs(a - b) < 0.001, `${msg ?? ""} ${a} != ${b}`);
}

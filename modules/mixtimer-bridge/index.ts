import { requireOptionalNativeModule } from "expo";

type Bridge = {
  start(number: number, startAt: number): void;
  stop(): void;
};

const bridge = requireOptionalNativeModule<Bridge>("MixTimerBridge");

/** プリセット number（1〜6）を、startAt 番目（1〜）の区間から始める */
export function startPreset(number: number, startAt = 1) {
  bridge?.start(number, startAt);
}

export function stopTimer() {
  bridge?.stop();
}

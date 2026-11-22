import * as THREE from 'three';

export type MechanicalKind = 'button' | 'knob' | 'switch' | 'lever' | 'dial';

export interface MechanicalState {
  value: number;
  min: number;
  max: number;
}

export interface MechanicalPart {
  readonly kind: MechanicalKind;
  readonly object: THREE.Object3D;
  readonly state: MechanicalState;
  readonly interactId: string;
  update(value: number): void;
}

export interface MechanicalOptions {
  id: string;
  object: THREE.Object3D;
  kind: MechanicalKind;
  min?: number;
  max?: number;
  value?: number;
  onChange?: (value: number) => void;
}

/**
 * Maps a visible machine control to a bounded deterministic value.
 * Visual motion is deliberately simple; machine-specific actions remain in GameApi.
 */
export function createMechanicalPart(options: MechanicalOptions): MechanicalPart {
  const min = options.min ?? 0;
  const max = options.max ?? 1;
  let value = clamp(options.value ?? min, min, max);

  const update = (next: number): void => {
    value = clamp(next, min, max);
    applyMotion(options.object, options.kind, value, min, max);
    options.onChange?.(value);
  };

  const part: MechanicalPart = {
    kind: options.kind,
    object: options.object,
    state: {
      get value() {
        return value;
      },
      min,
      max,
    },
    interactId: options.id,
    update,
  };
  update(value);
  return part;
}

function applyMotion(object: THREE.Object3D, kind: MechanicalKind, value: number, min: number, max: number): void {
  const t = max === min ? 0 : (value - min) / (max - min);
  switch (kind) {
    case 'button':
      object.position.y = object.userData['restY'] ?? object.position.y;
      object.position.y -= (1 - t) * 0.035;
      break;
    case 'knob':
    case 'dial':
      object.rotation.z = THREE.MathUtils.lerp(-Math.PI * 0.65, Math.PI * 0.65, t);
      break;
    case 'switch':
      object.rotation.x = THREE.MathUtils.lerp(-0.45, 0.45, t);
      break;
    case 'lever':
      object.rotation.z = THREE.MathUtils.lerp(-0.7, 0.7, t);
      break;
  }
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

import { describe, expect, it } from 'vitest';
import * as THREE from 'three';
import { createMechanicalPart } from '../src/world/mechanical';

describe('mechanical parts', () => {
  it('clamps a button to its configured range and moves it physically', () => {
    const object = new THREE.Object3D();
    object.userData['restY'] = 1;
    const part = createMechanicalPart({
      id: 'start',
      object,
      kind: 'button',
      min: 0,
      max: 1,
      value: 0,
    });

    part.update(2);

    expect(part.state.value).toBe(1);
    expect(object.position.y).toBe(1);
  });

  it('maps a dial value to a bounded rotation', () => {
    const object = new THREE.Object3D();
    const part = createMechanicalPart({
      id: 'frequency',
      object,
      kind: 'dial',
      min: 0,
      max: 100,
      value: 50,
    });

    expect(part.state.value).toBe(50);
    expect(object.rotation.z).toBeCloseTo(0);
  });
});

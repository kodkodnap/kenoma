export type AssetTier = 'hero' | 'mid' | 'background';

export interface AssetSpec {
  id: string;
  path: string;
  tier: AssetTier;
  maxTriangles: number;
  materials: number;
  interactiveParts: string[];
  states: string[];
}

/**
 * Source-of-truth checklist for Blender exports. Files stay optional at runtime
 * so the game can start without them. `sa9-spectrum` is authored: its source is
 * `blender/sa9-spectrum.blend` and `scripts/blender-sa9.py` rebuilds the GLB.
 */
export const ASSET_SPECS: readonly AssetSpec[] = [
  {
    id: 'sa9-spectrum',
    path: '/assets/machines/sa9-spectrum.glb',
    tier: 'hero',
    maxTriangles: 6500,
    materials: 4,
    interactiveParts: ['knob_frequency', 'button_isolate', 'display_spectrum'],
    states: ['normal', 'no-power', 'fault', 'sabotaged', 'repaired'],
  },
  {
    id: 'dm4-demodulator',
    path: '/assets/machines/dm4-demodulator.glb',
    tier: 'hero',
    maxTriangles: 5500,
    materials: 4,
    interactiveParts: ['switch_mode', 'button_confirm', 'display_waveform'],
    states: ['normal', 'no-power', 'fault', 'sabotaged', 'repaired'],
  },
  {
    id: 'pd2-decoder',
    path: '/assets/machines/pd2-decoder.glb',
    tier: 'hero',
    maxTriangles: 6000,
    materials: 4,
    interactiveParts: ['knob_signature', 'button_decode', 'tray_capture'],
    states: ['normal', 'no-power', 'fault', 'sabotaged', 'repaired'],
  },
  {
    id: 'dish-kestrel',
    path: '/assets/station/dish-kestrel.glb',
    tier: 'hero',
    maxTriangles: 9000,
    materials: 5,
    interactiveParts: ['wheel_azimuth', 'wheel_elevation', 'button_record', 'display_lock'],
    states: ['normal', 'no-power', 'recording', 'locked'],
  },
  {
    id: 'pine-kit',
    path: '/assets/environment/pine-kit.glb',
    tier: 'mid',
    maxTriangles: 900,
    materials: 2,
    interactiveParts: [],
    states: ['snow', 'wind'],
  },
];

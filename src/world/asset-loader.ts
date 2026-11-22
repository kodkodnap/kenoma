import * as THREE from 'three';
import { GLTFLoader, type GLTF } from 'three/examples/jsm/loaders/GLTFLoader.js';

export interface AssetLoadOptions {
  fallback?: () => THREE.Object3D;
  onProgress?: (loaded: number, total: number) => void;
}

/**
 * Loads original GLB assets without making the game depend on them at startup.
 * A caller may provide a procedural fallback while an asset is unavailable.
 */
export class AssetLoader {
  private readonly loader = new GLTFLoader();
  private readonly cache = new Map<string, Promise<GLTF>>();

  load(path: string, options: AssetLoadOptions = {}): Promise<THREE.Object3D> {
    const cached = this.cache.get(path) ?? this.loadGltf(path, options.onProgress);
    this.cache.set(path, cached);
    return cached
      .then((gltf) => gltf.scene.clone(true))
      .catch((error: unknown) => {
        if (options.fallback) return options.fallback();
        throw error;
      });
  }

  clear(path?: string): void {
    if (path) {
      this.cache.delete(path);
      return;
    }
    this.cache.clear();
  }

  private loadGltf(path: string, onProgress?: (loaded: number, total: number) => void): Promise<GLTF> {
    return this.loader.loadAsync(path, onProgress
      ? (event) => onProgress(event.loaded, event.total)
      : undefined);
  }
}

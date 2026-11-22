// Estadísticas de un GLB: nodos, materiales, triángulos y caja envolvente en metros.
// Uso: node scripts/glb-stats.mjs public/assets/machines/sa9-spectrum.glb

import { readFileSync } from 'node:fs';

const path = process.argv[2];
if (!path) {
  console.error('uso: node scripts/glb-stats.mjs <archivo.glb>');
  process.exit(2);
}

const buffer = readFileSync(path);
if (buffer.readUInt32LE(0) !== 0x46546c67) {
  console.error('no es un GLB');
  process.exit(1);
}

const jsonLength = buffer.readUInt32LE(12);
const json = JSON.parse(buffer.subarray(20, 20 + jsonLength).toString('utf8'));
const nodes = json.nodes ?? [];
const accessors = json.accessors ?? [];

// ---------- matrices 4x4 en columna (como glTF) ----------
const IDENTITY = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];

function multiply(a, b) {
  const out = new Array(16).fill(0);
  for (let column = 0; column < 4; column += 1) {
    for (let row = 0; row < 4; row += 1) {
      let sum = 0;
      for (let k = 0; k < 4; k += 1) sum += a[k * 4 + row] * b[column * 4 + k];
      out[column * 4 + row] = sum;
    }
  }
  return out;
}

function localMatrix(node) {
  if (node.matrix) return node.matrix;
  const [tx, ty, tz] = node.translation ?? [0, 0, 0];
  const [x, y, z, w] = node.rotation ?? [0, 0, 0, 1];
  const [sx, sy, sz] = node.scale ?? [1, 1, 1];
  const xx = x * x;
  const yy = y * y;
  const zz = z * z;
  const xy = x * y;
  const xz = x * z;
  const yz = y * z;
  const wx = w * x;
  const wy = w * y;
  const wz = w * z;
  return [
    (1 - 2 * (yy + zz)) * sx, 2 * (xy + wz) * sx, 2 * (xz - wy) * sx, 0,
    2 * (xy - wz) * sy, (1 - 2 * (xx + zz)) * sy, 2 * (yz + wx) * sy, 0,
    2 * (xz + wy) * sz, 2 * (yz - wx) * sz, (1 - 2 * (xx + yy)) * sz, 0,
    tx, ty, tz, 1,
  ];
}

function transform(matrix, point) {
  const [x, y, z] = point;
  return [
    matrix[0] * x + matrix[4] * y + matrix[8] * z + matrix[12],
    matrix[1] * x + matrix[5] * y + matrix[9] * z + matrix[13],
    matrix[2] * x + matrix[6] * y + matrix[10] * z + matrix[14],
  ];
}

// ---------- triángulos ----------
let triangles = 0;
const perMesh = [];
for (const mesh of json.meshes ?? []) {
  let meshTriangles = 0;
  for (const primitive of mesh.primitives) {
    const count = primitive.indices != null
      ? accessors[primitive.indices].count
      : accessors[primitive.attributes.POSITION].count;
    meshTriangles += count / 3;
  }
  triangles += meshTriangles;
  perMesh.push({ name: mesh.name, triangles: meshTriangles, primitives: mesh.primitives.length });
}

// ---------- caja envolvente en espacio de mundo ----------
const min = [Infinity, Infinity, Infinity];
const max = [-Infinity, -Infinity, -Infinity];

function walk(index, parentMatrix) {
  const node = nodes[index];
  const world = multiply(parentMatrix, localMatrix(node));
  if (node.mesh != null) {
    for (const primitive of json.meshes[node.mesh].primitives) {
      const accessor = accessors[primitive.attributes.POSITION];
      for (let corner = 0; corner < 8; corner += 1) {
        const point = [
          (corner & 1 ? accessor.max : accessor.min)[0],
          (corner & 2 ? accessor.max : accessor.min)[1],
          (corner & 4 ? accessor.max : accessor.min)[2],
        ];
        const moved = transform(world, point);
        for (let axis = 0; axis < 3; axis += 1) {
          min[axis] = Math.min(min[axis], moved[axis]);
          max[axis] = Math.max(max[axis], moved[axis]);
        }
      }
    }
  }
  for (const child of node.children ?? []) walk(child, world);
}

for (const scene of json.scenes ?? []) {
  for (const index of scene.nodes ?? []) walk(index, IDENTITY);
}

const round = (value) => Number(value.toFixed(3));
const size = min.map((lo, axis) => round(max[axis] - lo));

console.log(JSON.stringify({
  file: path,
  bytes: buffer.length,
  nodes: nodes.map((node) => node.name),
  meshes: perMesh,
  materials: (json.materials ?? []).map((material) => material.name),
  extensions: json.extensionsUsed ?? [],
  triangles,
  size_meters: { width: size[0], height: size[1], depth: size[2] },
  min: min.map(round),
  max: max.map(round),
}, null, 2));

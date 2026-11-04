#!/usr/bin/env python3
"""Validate the shipped 3D library without Blender, Godot, or third-party packages."""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import re
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets' / 'models'
PIVOTS = {'Torso', 'Head', 'Arm_L', 'Arm_R', 'Leg_L', 'Leg_R'}
APPEARANCE = {'skin', 'hair', 'shirt', 'trousers', 'shoes'}
RESIDENTS = {'resident', 'resident_bob', 'resident_curls', 'resident_shaved'}
LIMITS = {'resident_triangles': 8000, 'static_triangles': 12000, 'meshes': 20, 'bytes': 1_500_000}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def glb(path: Path) -> tuple[dict, bytes]:
    data = path.read_bytes()
    require(not data.startswith(b'version https://git-lfs.github.com/spec'),
            f'{path.name}: unresolved Git LFS pointer; run git lfs pull')
    require(len(data) >= 28, f'{path.name}: truncated GLB')
    magic, version, length = struct.unpack_from('<4sII', data)
    require(magic == b'glTF' and version == 2 and length == len(data), f'{path.name}: invalid GLB header')
    require(len(data) <= LIMITS['bytes'], f'{path.name}: file exceeds reviewed byte budget')
    chunks = []
    cursor = 12
    while cursor < length:
        require(cursor + 8 <= length, f'{path.name}: truncated chunk header')
        size, kind = struct.unpack_from('<I4s', data, cursor)
        cursor += 8
        require(size % 4 == 0 and cursor + size <= length, f'{path.name}: invalid chunk extent')
        chunks.append((kind, data[cursor:cursor + size]))
        cursor += size
    require([c[0] for c in chunks] == [b'JSON', b'BIN\x00'], f'{path.name}: expected embedded JSON and binary chunks')
    document = json.loads(chunks[0][1])
    require(document['asset']['version'] == '2.0', f'{path.name}: unsupported glTF version')
    require(len(document.get('buffers', [])) == 1 and 'uri' not in document['buffers'][0], f'{path.name}: external geometry')
    require(document['buffers'][0]['byteLength'] <= len(chunks[1][1]), f'{path.name}: missing embedded bytes')
    require(not document.get('images') and not document.get('textures'), f'{path.name}: this collection uses modeled detail, not texture dependencies')
    require(not document.get('cameras') and not document.get('animations'), f'{path.name}: unexpected camera or animation')
    for view in document.get('bufferViews', []):
        start, size = view.get('byteOffset', 0), view['byteLength']
        require(view['buffer'] == 0 and start >= 0 and size > 0 and start + size <= len(chunks[1][1]), f'{path.name}: buffer view outside binary')
    return document, chunks[1][1]


def accessor(document: dict, binary: bytes, index: int) -> list[tuple]:
    item = document['accessors'][index]
    require('sparse' not in item, 'Sparse accessors need a reviewed validator update')
    formats = {5121: 'B', 5123: 'H', 5125: 'I', 5126: 'f'}
    widths = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}
    fmt = '<' + formats[item['componentType']] * widths[item['type']]
    size = struct.calcsize(fmt)
    view = document['bufferViews'][item['bufferView']]
    stride = view.get('byteStride', size)
    relative = item.get('byteOffset', 0)
    count = item['count']
    require(count > 0 and relative >= 0 and stride >= size and relative + (count - 1) * stride + size <= view['byteLength'], 'Accessor outside its buffer view')
    start = view.get('byteOffset', 0) + relative
    result = [struct.unpack_from(fmt, binary, start + i * stride) for i in range(count)]
    require(all(math.isfinite(value) for row in result for value in row), 'Non-finite geometry')
    return result


def transform_point(point: tuple, node: dict) -> tuple:
    if 'matrix' in node:
        m = node['matrix']; x, y, z = point
        return tuple(m[i] * x + m[4 + i] * y + m[8 + i] * z + m[12 + i] for i in range(3))
    scale = node.get('scale', [1, 1, 1])
    v = tuple(point[i] * scale[i] for i in range(3))
    qx, qy, qz, qw = node.get('rotation', [0, 0, 0, 1])
    # Unit quaternion rotation: v + 2 * cross(q.xyz, cross(q.xyz, v) + qw*v).
    def cross(a, b):
        return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
    uv = cross((qx, qy, qz), v)
    uuv = cross((qx, qy, qz), uv)
    translation = node.get('translation', [0, 0, 0])
    return tuple(v[i] + 2 * (qw * uv[i] + uuv[i]) + translation[i] for i in range(3))


def inspect(name: str, entry: dict) -> int:
    path = ASSETS / entry['file']
    require(path.parent == ASSETS and path.suffix == '.glb' and path.stem == name, f'{name}: unexpected asset path')
    require(hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256'], f'{name}: changed asset; regenerate manifest from source')
    document, binary = glb(path)
    materials = {m['name'] for m in document.get('materials', [])}
    require(materials == set(entry['materials']), f'{name}: material manifest drift')
    meshes = document.get('meshes', [])
    require(0 < len(meshes) == entry['meshes'] <= LIMITS['meshes'], f'{name}: mesh/draw-call budget exceeded or manifest drift')
    positions = {}
    triangles = 0
    for i, mesh in enumerate(meshes):
        vertices = []
        for primitive in mesh['primitives']:
            require(primitive.get('mode', 4) == 4, f'{name}: geometry must be triangles')
            require('POSITION' in primitive['attributes'] and 'NORMAL' in primitive['attributes'], f'{name}: missing positions/normals')
            points = accessor(document, binary, primitive['attributes']['POSITION'])
            require(all(len(p) == 3 for p in points), f'{name}: non-3D vertices')
            normals = accessor(document, binary, primitive['attributes']['NORMAL'])
            require(len(normals) == len(points), f'{name}: missing vertex normals')
            indices = [x[0] for x in accessor(document, binary, primitive['indices'])]
            require(len(indices) % 3 == 0 and min(indices) >= 0 and max(indices) < len(points), f'{name}: invalid triangles')
            require(0 <= primitive['material'] < len(document['materials']), f'{name}: invalid material index')
            triangles += len(indices) // 3
            vertices.extend(points)
        positions[i] = vertices
    budget = LIMITS['resident_triangles'] if name in RESIDENTS else LIMITS['static_triangles']
    require(0 < triangles == entry['triangles'] <= budget, f'{name}: triangle budget exceeded or manifest drift ({triangles})')
    nodes = document['nodes']
    parents = {}
    for i, node in enumerate(nodes):
        for child in node.get('children', []):
            require(child not in parents and 0 <= child < len(nodes), f'{name}: invalid node hierarchy')
            parents[child] = i
    world_points = []
    for i, node in enumerate(nodes):
        if 'mesh' not in node:
            continue
        for point in positions[node['mesh']]:
            cursor = i; chain = set()
            while True:
                require(cursor not in chain, f'{name}: cyclic hierarchy')
                chain.add(cursor)
                point = transform_point(point, nodes[cursor])
                if cursor not in parents:
                    break
                cursor = parents[cursor]
            world_points.append(point)
    require(bool(world_points), f'{name}: no visible mesh nodes')
    bounds = {'min': [min(p[i] for p in world_points) for i in range(3)], 'max': [max(p[i] for p in world_points) for i in range(3)]}
    for side in ['min', 'max']:
        require(all(abs(bounds[side][i] - entry['bounds'][side][i]) < .001 for i in range(3)), f'{name}: geometric bounds mismatch')
    if name in RESIDENTS:
        named = {node.get('name'): i for i, node in enumerate(nodes)}
        require(PIVOTS <= named.keys(), f'{name}: missing animated pivot')
        require(all(nodes[named[p]].get('children') for p in PIVOTS), f'{name}: empty animated pivot')
        require(APPEARANCE <= materials, f'{name}: missing appearance material')
        require(entry['animated_pivots'] is True, f'{name}: missing animation contract')
        require(1.60 <= bounds['max'][1] <= 1.80 and -.01 <= bounds['min'][1] <= .04, f'{name}: unassembled or ungrounded resident')
    return triangles


def main() -> int:
    try:
        manifest = json.loads((ASSETS / 'manifest.json').read_text())
        require(manifest['schema'] == 1, 'Unsupported model manifest')
        require(hashlib.sha256((ROOT / manifest['source']).read_bytes()).hexdigest() == manifest['source_sha256'], 'Generator changed: regenerate GLBs and manifest')
        models = manifest['models']
        catalog = (ROOT / 'game' / 'catalog.gd').read_text()
        footprints = {kind: [int(x), int(z)] for kind, x, z in re.findall(r'^\s*"([a-z_]+)":.*?"size":\[(\d+),(\d+)\]', catalog, re.M)}
        require(bool(footprints), 'No catalog footprints found')
        for kind, footprint in footprints.items():
            if kind in {'floor', 'wall', 'door'}:
                continue
            require(kind in models and models[kind]['footprint'] == footprint, f'{kind}: missing model or wrong catalog footprint')
            require(any(m.startswith('custom_') for m in models[kind]['materials']), f'{kind}: missing recolorable material')
        require(RESIDENTS <= models.keys(), 'Missing resident appearance variants')
        require({'canvas'} <= set(models['easel']['materials']), 'Missing dynamic easel canvas')
        require({'soil'} <= set(models['garden_bed']['materials']), 'Missing garden moisture material')
        require(set(path.stem for path in ASSETS.glob('*.glb')) == set(models), 'Untracked or missing model in manifest')
        total = sum(inspect(name, entry) for name, entry in models.items())
        print(f'MODEL_LIBRARY_PASS: {len(models)} embedded GLBs; {len(footprints)-3} catalog furnishings; {total} triangles; hashes, bounds, pivots, materials and budgets verified')
        return 0
    except (AssertionError, KeyError, IndexError, OSError, TypeError, ValueError, struct.error) as error:
        print(f'MODEL_LIBRARY_FAIL: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())

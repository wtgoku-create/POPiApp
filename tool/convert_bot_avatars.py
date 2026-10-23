"""Rebuild the source idle motion as portable PNG + vector Lottie animations.

Requires Pillow. Usage:
  python3 tool/convert_bot_avatars.py /path/to/POPi-ThreeJS-avatar-motion-v4-expressions
"""

import argparse
import base64
import io
import json
import math
from pathlib import Path

from PIL import Image


FPS = 30
FRAMES = 240
SIZE = 512


def smoothstep(low, high, value):
    t = max(0, min(1, (value - low) / (high - low)))
    return t * t * (3 - 2 * t)


def linear(value):
    value /= 255
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def srgb(value):
    value = value * 12.92 if value <= 0.0031308 else 1.055 * value ** (1 / 2.4) - 0.055
    return round(max(0, min(1, value)) * 255)


def remove_eyes(source, eyes, cover_scale):
    """Bake the source shader's surrounding-skin sampling into the base image."""
    result = source.copy()

    def sample(x, y):
        x, y = max(0, min(SIZE - 1, x)), max(0, min(SIZE - 1, y))
        ix, iy = int(x), int(y)
        fx, fy = x - ix, y - iy
        colors = [source.getpixel((px, py)) for px, py in [
            (ix, iy), (min(ix + 1, SIZE - 1), iy),
            (ix, min(iy + 1, SIZE - 1)),
            (min(ix + 1, SIZE - 1), min(iy + 1, SIZE - 1)),
        ]]
        weights = [(1 - fx) * (1 - fy), fx * (1 - fy), (1 - fx) * fy, fx * fy]
        return [sum((linear(c[k]) if k < 3 else c[k] / 255) * w
                    for c, w in zip(colors, weights)) for k in range(4)]

    for eye in eyes:
        angle = math.radians(eye['angle'])
        axis = (math.cos(angle), math.sin(angle))
        normal = (-axis[1], axis[0])
        length = eye['length'] * cover_scale
        radius = (eye['width'] * cover_scale + 2) / 2
        half_segment = max(length / 2 - radius, 0)
        extent = math.ceil(length + 4)
        for y in range(max(0, int(eye['cy']) - extent), min(SIZE, int(eye['cy']) + extent)):
            for x in range(max(0, int(eye['cx']) - extent), min(SIZE, int(eye['cx']) + extent)):
                dx, dy = x - eye['cx'], y - eye['cy']
                local_x = dx * axis[0] + dy * axis[1]
                local_y = dx * normal[0] + dy * normal[1]
                distance = math.hypot(max(abs(local_x) - half_segment, 0), local_y) - radius
                cover = 1 - smoothstep(-1.15, 1.15, distance)
                if cover <= 0:
                    continue
                a = sample(x + normal[0] * (radius - local_y + 3),
                           y + normal[1] * (radius - local_y + 3))
                b = sample(x - normal[0] * (radius + local_y + 3),
                           y - normal[1] * (radius + local_y + 3))
                blend = smoothstep(-radius, radius, local_y)
                skin = [bv + (av - bv) * blend for av, bv in zip(a, b)]
                valid = smoothstep(.12, .75, skin[3])
                pixel = source.getpixel((x, y))
                amount = cover * pixel[3] / 255
                color = []
                for k in range(3):
                    fill = linear(eye['fill'][k])
                    stabilized = fill + (skin[k] - fill) * .78 * valid
                    color.append(srgb(linear(pixel[k]) * (1 - amount) + stabilized * amount))
                result.putpixel((x, y), (*color, pixel[3]))
    return result


def static(value):
    return {'a': 0, 'k': value}


def animated(values):
    # Linear interpolation between samples preserves the shader's blink curve.
    # Hold the final displayed frame: players treat the out-point as exclusive.
    start = values[0][1]
    values = [(t, v) for t, v in values if t < FRAMES - 1]
    values.extend([(FRAMES - 1, start), (FRAMES, start)])
    values = [item for i, item in enumerate(values)
              if i == 0 or i == len(values) - 1
              or item[1] != values[i - 1][1] or item[1] != values[i + 1][1]]
    return {'a': 1, 'k': [
        {'t': t, 's': value if isinstance(value, list) else [value],
         'o': {'x': .333333, 'y': .333333}, 'i': {'x': .666667, 'y': .666667}}
        for t, value in values
    ]}


def animated_position(values):
    # Separate axes avoid path-metric float rounding at the loop boundary.
    return {'s': True, **{
        axis: animated([(frame, position[index]) for frame, position in values])
        for index, axis in enumerate(('x', 'y'))
    }}


def transform(position=(0, 0, 0), anchor=(0, 0, 0), rotation=0, scale=(100, 100, 100)):
    return {'o': static(100), 'p': static(list(position)), 'a': static(list(anchor)),
            'r': static(rotation), 's': static(list(scale))}


def layer(index, kind, name, ks, **fields):
    return {'ddd': 0, 'ind': index, 'ty': kind, 'nm': name, 'ks': ks,
            'ip': 0, 'op': FRAMES, 'st': 0, 'sr': 1, **fields}


def closure(time):
    if time < 0 or time > .24:
        return 0
    if time < .065:
        return math.sin(time / .065 * math.pi / 2)
    if time < .095:
        return 1
    return math.cos((time - .095) / .145 * math.pi / 2)


def build_animation(source, avatar, cover_scale):
    base = remove_eyes(source, avatar['eyes'], cover_scale)
    buffer = io.BytesIO()
    base.save(buffer, format='PNG', optimize=True)
    image_data = base64.b64encode(buffer.getvalue()).decode('ascii')
    parent = transform(position=(256, 256, 0), anchor=(256, 256, 0), scale=(87.5, 87.5, 100))
    # Whole cycles close the loop without a jump at the eight-second boundary.
    parent['r'] = animated([(f, math.sin(f / FRAMES * math.tau) * 1.49) for f in range(0, FRAMES + 1, 4)])
    parent['p'] = animated_position([(f, [256, 256 - math.sin(f / FRAMES * math.tau * 2) * 4.48, 0])
                            for f in range(0, FRAMES + 1, 4)])
    layers = []
    for index, eye in enumerate(avatar['eyes']):
        dimensions, rotations = [], []
        for frame in range(FRAMES + 1):
            time = frame / FPS
            openness = 1 - max(closure(time - at - index * .018) for at in (2.7, 6.15))
            open_blend = smoothstep(.12, .62, openness)
            length = max(eye['width'] * .88, 17) * (1 - open_blend) + eye['length'] * open_blend
            width = 4.8 + (eye['width'] - 4.8) * smoothstep(.08, .38, openness)
            dimensions.append((frame, [length, width]))
            rotations.append((frame, eye['angle'] - 90 * (1 - open_blend)))
        ks = transform()
        ks['p'] = animated_position([(f, [eye['cx'] + 3 + math.sin(f / FRAMES * math.tau) * 1.7,
                                  eye['cy'] + math.sin(f / FRAMES * math.tau) * 1.1, 0])
                             for f in range(0, FRAMES + 1, 4)])
        ks['r'] = animated(rotations)
        ink = source.getpixel((round(eye['cx']), round(eye['cy'])))
        layers.append(layer(index + 1, 4, f'eye-{index + 1}', ks, parent=10, shapes=[
            {'ty': 'rc', 'd': 1, 'p': static([0, 0]), 's': animated(dimensions),
             'r': static(100), 'nm': 'capsule'},
            {'ty': 'fl', 'c': static([v / 255 for v in ink[:3]] + [1]), 'o': static(100), 'r': 1},
        ]))
    layers.append(layer(3, 2, 'skin-without-eyes', transform(), parent=10, refId='skin'))
    layers.append(layer(10, 3, 'idle-body', parent))
    return {
        'v': '5.12.2', 'fr': FPS, 'ip': 0, 'op': FRAMES, 'w': SIZE, 'h': SIZE,
        'nm': f"POPi {avatar['name']} idle", 'ddd': 0,
        'assets': [{'id': 'skin', 'w': SIZE, 'h': SIZE, 'u': '', 'e': 1,
                    'p': 'data:image/png;base64,' + image_data}],
        'layers': layers, 'markers': [{'tm': 0, 'cm': 'idle', 'dr': FRAMES}],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--output', type=Path,
                        default=Path(__file__).resolve().parent.parent / 'assets/animations/bot_avatars')
    args = parser.parse_args()
    metadata = json.loads((args.source / 'eye-metadata.json').read_text())
    if metadata['sourceSize'] != SIZE:
        parser.error('Expected 512px source artwork and matching eye metadata')
    args.output.mkdir(parents=True, exist_ok=True)
    for avatar in metadata['avatars']:
        source = Image.open(args.source / 'assets/avatars' / avatar['file']).convert('RGBA')
        if source.size != (SIZE, SIZE):
            parser.error(f"Unexpected dimensions for {avatar['file']}: {source.size}")
        animation = build_animation(source, avatar, metadata['coverScale'])
        name = avatar['name']
        (args.output / f'{name}.json').write_text(json.dumps(animation, separators=(',', ':')) + '\n')
        # The same framing as the Lottie at frame zero, for reduced motion/fallback.
        still = Image.new('RGBA', (SIZE, SIZE))
        still.alpha_composite(source.resize((448, 448), Image.Resampling.LANCZOS), (32, 32))
        still.save(args.output / f'{name}.png', optimize=True)
        print(f'{name}: {(args.output / f"{name}.json").stat().st_size:,} bytes')


if __name__ == '__main__':
    main()

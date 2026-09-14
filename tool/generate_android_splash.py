"""Convert the existing brand SVG to an Android splash vector without reshaping it."""

from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ANDROID = 'http://schemas.android.com/apk/res/android'
AAPT = 'http://schemas.android.com/aapt'
SVG = {'svg': 'http://www.w3.org/2000/svg'}
ET.register_namespace('android', ANDROID)
ET.register_namespace('aapt', AAPT)


def attrs(**values):
    return {f'{{{ANDROID}}}{key}': str(value) for key, value in values.items()}


source = ET.parse(ROOT / 'assets/icons/home_welcome_logo.svg').getroot()
vector = ET.Element('vector', attrs(width='288dp', height='288dp',
                                    viewportWidth=288, viewportHeight=288))
# Keep the 90 x 59.625 dp logo within Android 12's circular safe area.
group = ET.SubElement(vector, 'group', attrs(scaleX=1.125, scaleY=1.125,
                                          translateX=99, translateY=114.1875))
gradients = {g.attrib['id']: g for g in source.findall('.//svg:linearGradient', SVG)}
for path in source.findall('.//svg:path', SVG):
    fill = path.attrib['fill']
    target = ET.SubElement(group, 'path', attrs(pathData=path.attrib['d']))
    if not fill.startswith('url('):
        target.set(f'{{{ANDROID}}}fillColor', '#FFFFFF' if fill == 'white' else fill)
        continue
    gradient = gradients[fill[5:-1]]
    item = ET.SubElement(target, f'{{{AAPT}}}attr', {'name': 'android:fillColor'})
    native = ET.SubElement(item, 'gradient', attrs(
        type='linear', startX=gradient.attrib['x1'], startY=gradient.attrib['y1'],
        endX=gradient.attrib['x2'], endY=gradient.attrib['y2']))
    for stop in gradient.findall('svg:stop', SVG):
        ET.SubElement(native, 'item', attrs(offset=stop.attrib['offset'],
                                          color=stop.attrib['stop-color']))

ET.indent(vector)
ET.ElementTree(vector).write(
    ROOT / 'android/app/src/main/res/drawable/splash_logo.xml',
    encoding='utf-8', xml_declaration=True)

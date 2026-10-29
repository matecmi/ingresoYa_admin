"""Copia en el admin las piezas de la app que se muestran en la vista previa.

La vista previa del admin debe ser idéntica a la app (pedido de Kevin): en vez
de dibujarla a mano, este script toma el código real de `../iya-app` y lo
adapta (imports del admin y textos del ARB en español en lugar de `l10n`).

Uso, desde la raíz del admin:
    python tool/sync_app_preview.py          # regenera lib/src/app_preview/gen
    python tool/sync_app_preview.py --check  # falla si la copia quedó vieja

Volver a correrlo cada vez que cambie en la app el tema, el renderizador de
preguntas, los widgets del examen, el búho o las piezas de las noticias.
"""

import json
import re
import subprocess
import sys
from pathlib import Path

ADMIN = Path(__file__).resolve().parents[1]
APP = ADMIN.parent / 'iya-app'
OUT = ADMIN / 'lib' / 'src' / 'app_preview' / 'gen'

SOURCES = {
    'app_theme.g.dart': ('lib/config/theme/app_theme.dart', None),
    'question_content_renderer.g.dart': (
        'lib/features/questions/presentation/widgets/question_content_renderer.dart',
        None,
    ),
    'owl_mascot.g.dart': ('lib/app/widgets/owl_mascot.dart', None),
    'news_visuals.g.dart': (
        'lib/features/news/presentation/widgets/news_visuals.dart',
        None,
    ),
    'part_exam_widgets.g.dart': (
        'lib/features/simulator/presentation/pages/exam_view/part_exam_attempt_widgets.dart',
        ['PartExamAlternativeTile', 'PartExamProgressHeader', 'PartExamSourceCard'],
    ),
}


def load_arb():
    arb = json.loads((APP / 'lib' / 'l10n' / 'app_es.arb').read_text(encoding='utf-8'))
    return arb


def dart_string(text):
    return "'" + text.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"


def split_args(s):
    args, depth, cur = [], 0, ''
    for ch in s:
        if ch in '([{':
            depth += 1
        elif ch in ')]}':
            depth -= 1
        if ch == ',' and depth == 0:
            args.append(cur.strip())
            cur = ''
        else:
            cur += ch
    if cur.strip():
        args.append(cur.strip())
    return args


def plural_cases(text):
    """«{count, plural, =1{…} other{…}}» → ('count', [('1', '…'), ('_', '…')])."""
    m = re.match(r'^\{(\w+), plural,(.*)\}$', text, re.S)
    if not m:
        return None
    name, body, cases, i = m.group(1), m.group(2), [], 0
    while i < len(body):
        sel = re.match(r'\s*(=\d+|other)\{', body[i:])
        if not sel:
            break
        start = i + sel.end()
        depth, k = 1, start
        while depth:
            depth += {'{': 1, '}': -1}.get(body[k], 0)
            k += 1
        key = '_' if sel.group(1) == 'other' else sel.group(1)[1:]
        cases.append((key, body[start:k - 1]))
        i = k
    return name, cases


def replace_l10n(src, arb):
    out, i = '', 0
    pattern = re.compile(r'(context\.l10n|appStrings|l10n)\.([A-Za-z0-9_]+)')
    while True:
        m = pattern.search(src, i)
        if not m:
            out += src[i:]
            return out
        key = m.group(2)
        if key not in arb:
            out += src[i:m.end()]
            i = m.end()
            continue
        out += src[i:m.start()]
        text = arb[key]
        meta = arb.get('@' + key, {})
        placeholders = list((meta.get('placeholders') or {}).keys())
        j = m.end()
        if j < len(src) and src[j] == '(':
            depth, k = 0, j
            while True:
                if src[k] == '(':
                    depth += 1
                elif src[k] == ')':
                    depth -= 1
                    if depth == 0:
                        break
                k += 1
            args = split_args(src[j + 1:k])
            if not placeholders:
                placeholders = re.findall(r'\{(\w+)\}', text)
            plural = plural_cases(text)
            if plural:
                name, cases = plural
                arg = dict(zip(placeholders or [name], args)).get(name, args[0])
                arms = []
                for key, case in cases:
                    value = dart_string(case)
                    value = value.replace('{' + name + '}', '${' + arg + '}')
                    arms.append(f'{key} => {value}')
                out += '(switch (' + arg + ') { ' + ', '.join(arms) + ' })'
            else:
                value = dart_string(text)
                for name, arg in zip(placeholders, args):
                    value = value.replace('{' + name + '}', '${' + arg + '}')
                out += value
            i = k + 1
        else:
            out += dart_string(text)
            i = j


def extract_classes(src, names):
    blocks = []
    for name in names:
        start = src.index('class ' + name + ' ')
        brace = src.index('{', start)
        depth, k = 0, brace
        while True:
            if src[k] == '{':
                depth += 1
            elif src[k] == '}':
                depth -= 1
                if depth == 0:
                    break
            k += 1
        blocks.append(src[start:k + 1])
    imports = '\n'.join(l for l in src.splitlines() if l.startswith('import '))
    return imports + '\n\n' + '\n\n'.join(blocks) + '\n'


def adapt(src, arb, rel, commit):
    src = replace_l10n(src, arb)
    src = re.sub(r"import 'package:ingresoya/l10n/l10n\.dart';\n?", '', src)
    src = re.sub(r"import '(whiteboard|widgets/stroke)\.dart';\n?", '', src)
    src = src.replace(
        "import 'package:ingresoya/shared/question_contract/question_contract.dart';",
        "import 'package:ingresoya_admin/shared/question_contract/question_contract.dart';",
    )
    src = src.replace(
        "import 'package:ingresoya/config/theme/app_theme.dart';",
        "import 'app_theme.g.dart';",
    )
    src = src.replace(
        "import 'package:ingresoya/app/widgets/owl_mascot.dart';",
        "import 'owl_mascot.g.dart';",
    )
    src = src.replace(
        "import 'package:ingresoya/features/questions/presentation/widgets/question_content_renderer.dart';",
        "import 'question_content_renderer.g.dart';",
    )
    # La web del admin no usa la caché de disco de la app: CachedNetworkImage
    # pasa a Image.network con el mismo fondo mientras carga y el mismo error.
    if 'CachedNetworkImage(' in src:
        src = re.sub(r"import 'package:cached_network_image/cached_network_image\.dart';\n?", '', src)
        src = src.replace('CachedNetworkImage(\n      imageUrl: url,', 'Image.network(\n      url,')
        src = src.replace('memCacheWidth: memCacheWidth,', 'cacheWidth: memCacheWidth,')
        src = src.replace(
            'placeholder: (context, url) => ColoredBox(color: colors.elevatedSurface),',
            'loadingBuilder: (context, child, progress) =>\n'
            '          progress == null ? child : ColoredBox(color: colors.elevatedSurface),',
        )
        src = src.replace('errorWidget: (context, url, error) =>', 'errorBuilder: (context, error, stack) =>')
        if 'CachedNetworkImage' in src:
            raise SystemExit('news_visuals: CachedNetworkImage cambió; actualiza adapt() del sync.')
    header = (
        '// GENERADO por tool/sync_app_preview.py — NO EDITAR A MANO.\n'
        f'// Copia fiel de iya-app/{rel} (commit {commit}) para que la vista\n'
        '// previa del admin sea idéntica a la app. Textos tomados de app_es.arb.\n'
        '// ignore_for_file: type=lint, deprecated_member_use\n\n'
    )
    return header + src


def main():
    check = '--check' in sys.argv
    if not APP.exists():
        print('No se encontró ../iya-app; nada que sincronizar.')
        return 0
    arb = load_arb()
    commit = subprocess.run(
        ['git', '-C', str(APP), 'log', '-1', '--format=%h'],
        capture_output=True, text=True,
    ).stdout.strip() or 'desconocido'
    OUT.mkdir(parents=True, exist_ok=True)
    stale = []
    for out_name, (rel, classes) in SOURCES.items():
        src = (APP / rel).read_text(encoding='utf-8')
        if classes:
            src = extract_classes(src, classes)
        text = adapt(src, arb, rel, commit)
        target = OUT / out_name
        current = target.read_text(encoding='utf-8') if target.exists() else ''
        strip = lambda t: re.sub(r'\(commit [0-9a-f]+\)', '', t)
        if strip(current) != strip(text):
            stale.append(out_name)
            if not check:
                target.write_text(text, encoding='utf-8')
    if check and stale:
        print('Vista previa desactualizada respecto de la app:', ', '.join(stale))
        print('Corre: python tool/sync_app_preview.py')
        return 1
    print('Actualizados:' if stale else 'Al día.', ', '.join(stale))
    return 0


if __name__ == '__main__':
    sys.exit(main())

#!/usr/bin/env python3
# Convierte documentacion/ENCENDER-Y-APAGAR.md en una página que se abre
# de un clic y se puede imprimir.
#
# POR QUÉ UNO PROPIO Y NO «pandoc»
#
# Este equipo no tiene pandoc ni ningún convertidor de markdown, y el
# manual usa cuatro cosas contadas: títulos, bloques de código, tablas y
# citas. Instalar un programa entero para eso —y que haga falta en toda
# máquina donde se quiera rehacer— es peor que estas ochenta líneas.
import html, re, sys, pathlib

ENTRADA = pathlib.Path(sys.argv[1])
SALIDA  = pathlib.Path(sys.argv[2])

CABECERA = """<!DOCTYPE html><html lang="es"><head><meta charset="utf-8">
<title>Encender y apagar — RedHornoma</title>
<style>
 body{max-width:44rem;margin:0 auto;padding:2.5rem 1.5rem 6rem;
      font:17px/1.65 system-ui,'DejaVu Sans',sans-serif;color:#1a2226;background:#fbfbfa}
 h1{font-size:2rem;color:#1c4b5a;border-bottom:3px solid #2e7d8f;padding-bottom:.4rem;margin-top:2.5rem}
 h2{font-size:1.35rem;color:#1c4b5a;margin-top:2.2rem}
 h3{font-size:1.1rem;color:#2e7d8f;margin-top:1.6rem}
 pre{background:#12303b;color:#e8f2f5;padding:1rem 1.1rem;border-radius:7px;
     overflow-x:auto;font:14.5px/1.55 'DejaVu Sans Mono',monospace}
 code{background:#e6edf0;padding:.12em .4em;border-radius:4px;
      font:.9em 'DejaVu Sans Mono',monospace;word-break:break-word}
 pre code{background:none;padding:0;color:inherit;font-size:1em}
 blockquote{border-left:5px solid #2e7d8f;background:#eef5f7;margin:1.3rem 0;
            padding:.8rem 1.1rem;border-radius:0 6px 6px 0}
 blockquote p{margin:.3rem 0}
 table{border-collapse:collapse;width:100%;margin:1.3rem 0;font-size:.95rem}
 th{background:#1c4b5a;color:#fff;text-align:left}
 th,td{border:1px solid #cfdade;padding:.6rem .7rem;vertical-align:top}
 tr:nth-child(even) td{background:#f2f6f7}
 td code{font-size:.85em}
 hr{border:0;border-top:1px solid #d5dfe2;margin:2.5rem 0}
 /* Para imprimirlo y dejarlo al lado de la computadora. */
 @media print{body{max-width:none;padding:0;font-size:11pt;background:#fff}
              pre{background:#f0f0f0;color:#000;border:1px solid #bbb}
              h1,h2{page-break-after:avoid} pre,table{page-break-inside:avoid}}
</style></head><body>
"""

def enlinea(t):
    t = html.escape(t)
    t = re.sub(r'`([^`]+)`', r'<code>\1</code>', t)
    t = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', t)
    return t

lineas = ENTRADA.read_text(encoding='utf-8').split('\n')
salida, i, en_codigo = [CABECERA], 0, False

while i < len(lineas):
    l = lineas[i]
    if l.startswith('```'):
        if en_codigo: salida.append('</code></pre>'); en_codigo = False
        else:         salida.append('<pre><code>');   en_codigo = True
        i += 1; continue
    if en_codigo:
        salida.append(html.escape(l)); i += 1; continue

    if re.match(r'^\|.*\|$', l) and i+1 < len(lineas) and re.match(r'^\|[\s:|-]+\|$', lineas[i+1]):
        cab = [c.strip() for c in l.strip('|').split('|')]
        salida.append('<table><tr>' + ''.join(f'<th>{enlinea(c)}</th>' for c in cab) + '</tr>')
        i += 2
        while i < len(lineas) and re.match(r'^\|.*\|$', lineas[i]):
            cs = [c.strip() for c in lineas[i].strip('|').split('|')]
            salida.append('<tr>' + ''.join(f'<td>{enlinea(c)}</td>' for c in cs) + '</tr>')
            i += 1
        salida.append('</table>'); continue

    if l.startswith('> '):
        cita = []
        while i < len(lineas) and lineas[i].startswith('>'):
            cita.append(lineas[i].lstrip('>').strip()); i += 1
        salida.append('<blockquote><p>' + enlinea(' '.join(cita)) + '</p></blockquote>'); continue

    m = re.match(r'^(#{1,3}) (.*)$', l)
    if m:
        n = len(m.group(1)); salida.append(f'<h{n}>{enlinea(m.group(2))}</h{n}>'); i += 1; continue
    if l.strip() == '---': salida.append('<hr>'); i += 1; continue
    if not l.strip():      i += 1; continue

    parrafo = []
    while i < len(lineas) and lineas[i].strip() and not lineas[i].startswith(('#','```','|','>','---')):
        parrafo.append(lineas[i]); i += 1
    salida.append('<p>' + enlinea(' '.join(parrafo)) + '</p>')

if en_codigo: salida.append('</code></pre>')
salida.append('</body></html>')
SALIDA.write_text('\n'.join(salida), encoding='utf-8')
print(f"   ● {SALIDA}  ({SALIDA.stat().st_size // 1024} KB)")

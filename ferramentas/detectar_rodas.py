"""Acha onde ficam as caixas de roda em cada foto de carroceria.

As fotos vem sem roda. A caixa de roda aparece como uma MANCHA ESCURA E OPACA
dentro da silhueta -- o paralama interno e a estrutura do freio -- e nao como um
buraco: a base do carro segue reta por baixo dela.

Os concorrentes escuros na mesma foto sao a grade, a tomada de ar do para-choque
e o vidro. O que separa a roda deles e a posicao e o formato: caixa de roda
encosta no ponto mais baixo do carro e e quase tao alta quanto larga, enquanto
grade fica no meio da altura e e bem mais larga que alta.

Uso:
    python ferramentas/detectar_rodas.py                 # gera o .json
    python ferramentas/detectar_rodas.py --conferir      # + PNGs de conferencia

O resultado alimenta prototipo/rodas.json. A roda nunca e assada dentro da foto:
Roda e um slot de equipamento, entao a arte entra por cima em tempo de execucao.
"""

import json
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parent.parent
CARROS = RAIZ / "prototipo" / "cars"
SAIDA = RAIZ / "prototipo" / "rodas.json"

REDUCAO = 4        # analisa reduzido: 4x mais rapido e o ruido some
ALFA_MIN = 128
# O paralama interno NAO e confiavelmente escuro: em umas fotos e preto, em
# outras cinza claro. Um limiar unico nao serve para as duas -- baixo demais perde
# a caixa clara, alto demais funde carro inteiro numa mancha so. Entao tenta do
# mais escuro para o mais claro e para no primeiro que devolve um par plausivel.
LUMIARES = [78, 108, 140, 172]
AREA_MIN = 0.005   # fracao da area do carro
ASPECTO = (0.45, 2.2)
BASE_TOL = 0.30    # o fundo da mancha tem que estar nos ultimos 30% da altura


def componentes(dark):
    """Rotula manchas conectadas. BFS simples: a imagem ja vem reduzida."""
    alt, larg = dark.shape
    visto = np.zeros_like(dark, dtype=bool)
    saida = []
    for y0 in range(alt):
        for x0 in range(larg):
            if not dark[y0, x0] or visto[y0, x0]:
                continue
            fila = deque([(y0, x0)])
            visto[y0, x0] = True
            pix = []
            while fila:
                y, x = fila.popleft()
                pix.append((y, x))
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < alt and 0 <= nx < larg and dark[ny, nx] and not visto[ny, nx]:
                        visto[ny, nx] = True
                        fila.append((ny, nx))
            ys = np.fromiter((p[0] for p in pix), dtype=int)
            xs = np.fromiter((p[1] for p in pix), dtype=int)
            y0, y1 = int(ys.min()), int(ys.max())
            # A COROA do arco: a faixa mais alta da mancha. O centro dela e o eixo
            # da roda, e ao contrario da caixa delimitadora nao se desloca quando a
            # mancha vaza para a sombra ao lado.
            coroa = ys <= y0 + max(1, int((y1 - y0) * 0.16))
            saida.append({
                "area": len(pix),
                "x0": int(xs.min()), "x1": int(xs.max()),
                "y0": y0, "y1": y1,
                "eixo_x": float(xs[coroa].mean()),
            })
    return saida


def anchors_da_imagem(caminho):
    img = Image.open(caminho).convert("RGBA")
    larg_o, alt_o = img.size
    peq = img.resize((larg_o // REDUCAO, alt_o // REDUCAO), Image.BILINEAR)
    arr = np.array(peq, dtype=np.int16)
    alfa = arr[:, :, 3]
    lum = (arr[:, :, 0] * 3 + arr[:, :, 1] * 6 + arr[:, :, 2]) // 10

    corpo = alfa > ALFA_MIN
    if not corpo.any():
        return None
    cols = np.where(corpo.any(axis=0))[0]
    rows = np.where(corpo.any(axis=1))[0]
    cx0, cx1 = int(cols[0]), int(cols[-1])
    cy0, cy1 = int(rows[0]), int(rows[-1])
    larg_carro = cx1 - cx0 + 1
    alt_carro = cy1 - cy0 + 1
    area_carro = float(corpo.sum())

    for limiar in LUMIARES:
        cands = _candidatos(corpo, lum, limiar, cy0, cy1, alt_carro, area_carro)
        par = _melhor_par(cands, larg_carro)
        if par is not None:
            return _montar(par, cands, larg_o, alt_o, float(cy1 + 1) * REDUCAO)
    return {"rodas": [], "cands": [], "larg": larg_o, "alt": alt_o,
            "reducao": REDUCAO}


def _candidatos(corpo, lum, limiar, cy0, cy1, alt_carro, area_carro):
    escuro = corpo & (lum < limiar)
    # Vidro e teto ficam de fora: caixa de roda vive na metade de baixo.
    escuro[: cy0 + int(alt_carro * 0.42), :] = False

    cands = []
    for b in componentes(escuro):
        w = b["x1"] - b["x0"] + 1
        h = b["y1"] - b["y0"] + 1
        if b["area"] < area_carro * AREA_MIN:
            continue
        asp = w / float(h)
        if not (ASPECTO[0] <= asp <= ASPECTO[1]):
            continue
        # Caixa de roda encosta no chao do carro; grade e tomada de ar nao.
        if (cy1 - b["y1"]) > alt_carro * BASE_TOL:
            continue
        b["w"] = w
        b["h"] = h
        cands.append(b)
    return cands


## As duas rodas sao as duas maiores manchas LONGE uma da outra -- pegar so as
## duas maiores acha dois pedacos da mesma caixa de roda.
def _melhor_par(cands, larg_carro):
    if len(cands) < 2:
        return None
    cands.sort(key=lambda b: b["area"], reverse=True)
    melhor = None
    for i in range(len(cands)):
        for j in range(i + 1, len(cands)):
            a, b = cands[i], cands[j]
            dist = abs((a["x0"] + a["x1"]) - (b["x0"] + b["x1"])) * 0.5
            if dist < larg_carro * 0.18:
                continue
            nota = a["area"] + b["area"]
            if melhor is None or nota > melhor[0]:
                melhor = (nota, a, b)
    if melhor is None:
        return None
    return sorted([melhor[1], melhor[2]], key=lambda b: b["x0"])


## A roda vai do TOPO DO ARCO ate o CHAO, e os dois extremos estao medidos na
## propria foto: a coroa do arco vem da mancha, o chao e o ponto mais baixo da
## silhueta. Derivar o tamanho de proporcao generica (distancia entre eixos) dava
## roda pequena demais, flutuando dentro da caixa sem encostar no chao.
FOLGA_ARCO = 0.10    # o pneu nao encosta na lataria: sobra um dedo de folga
ACHATAMENTO = 0.70   # a roda em 3/4 aparece bem mais estreita que alta


def _montar(par, cands, larg_o, alt_o, chao_y):
    rodas = []
    for b in par:
        cx = b["eixo_x"] * REDUCAO
        topo = float(b["y0"]) * REDUCAO
        # altura da abertura do arco, medida nesta foto
        vao = max(chao_y - topo, 8.0)
        ry = vao * 0.5 * (1.0 - FOLGA_ARCO)
        rx = ry * ACHATAMENTO
        cy = chao_y - ry
        rodas.append({
            "cx": round(cx / larg_o, 5), "cy": round(cy / alt_o, 5),
            "rx": round(rx / larg_o, 5), "ry": round(ry / alt_o, 5),
        })
    return {"rodas": rodas, "cands": cands, "larg": larg_o, "alt": alt_o,
            "reducao": REDUCAO}


def conferir(caminho, dados, destino):
    img = Image.open(caminho).convert("RGBA")
    fundo = Image.new("RGBA", img.size, (24, 24, 28, 255))
    fundo.alpha_composite(img)
    d = ImageDraw.Draw(fundo)
    for b in dados.get("cands", []):
        r = dados["reducao"]
        d.rectangle([b["x0"] * r, b["y0"] * r, b["x1"] * r, b["y1"] * r],
                    outline=(70, 130, 255, 255), width=3)
    for r_ in dados["rodas"]:
        cx = r_["cx"] * dados["larg"]
        cy = r_["cy"] * dados["alt"]
        rx = r_["rx"] * dados["larg"]
        ry = r_["ry"] * dados["alt"]
        d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], outline=(255, 60, 40, 255), width=6)
        d.line([cx - 16, cy, cx + 16, cy], fill=(255, 200, 40, 255), width=4)
        d.line([cx, cy - 16, cx, cy + 16], fill=(255, 200, 40, 255), width=4)
    fundo.convert("RGB").save(destino)


def main():
    quer_conferir = "--conferir" in sys.argv
    pasta_conf = RAIZ / "ferramentas" / "conferencia"
    if quer_conferir:
        pasta_conf.mkdir(exist_ok=True)

    tudo = {}
    faltando = []
    for png in sorted(CARROS.glob("*.png")):
        dados = anchors_da_imagem(png)
        nome = png.stem
        if dados is None or len(dados["rodas"]) < 2:
            faltando.append(nome)
            print("%-24s SEM DETECCAO" % nome)
        else:
            tudo[nome] = dados["rodas"]
            print("%-24s %s" % (nome, "  ".join(
                "(%.3f, %.3f) r %.3f x %.3f" % (x["cx"], x["cy"], x["rx"], x["ry"])
                for x in dados["rodas"])))
        if quer_conferir and dados is not None:
            conferir(png, dados, pasta_conf / (nome + ".png"))

    SAIDA.write_text(json.dumps(tudo, indent="\t", ensure_ascii=False), encoding="utf-8")
    total = len(list(CARROS.glob("*.png")))
    print("\n%d de %d carros com roda detectada -> %s" % (len(tudo), total, SAIDA.name))
    if faltando:
        print("sem deteccao: " + ", ".join(faltando))


if __name__ == "__main__":
    main()

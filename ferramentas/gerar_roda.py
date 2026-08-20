"""Desenha a arte de roda usada por cima das carrocerias.

A roda e desenhada de frente e circular. O achatamento de 3/4 nao entra aqui:
ele vem da escala do sprite no jogo, que sai do arco medido em cada foto. Assim
uma arte so serve para os 25 carros.

    python ferramentas/gerar_roda.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "prototipo" / "roda.png"
LADO = 256
SS = 4  # supersampling: desenha grande e reduz, para a borda nao serrilhar


def main():
    n = LADO * SS
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = n / 2.0

    def circulo(raio, cor):
        d.ellipse([c - raio, c - raio, c + raio, c + raio], fill=cor)

    # pneu: preto fosco com um aro externo mais claro, para o contorno existir
    # contra a lataria branca e contra a pista escura
    circulo(n * 0.500, (16, 16, 18, 255))
    circulo(n * 0.478, (30, 30, 33, 255))
    # ombro do pneu
    circulo(n * 0.404, (22, 22, 25, 255))
    # parede lateral
    circulo(n * 0.392, (34, 34, 37, 255))

    # aro
    circulo(n * 0.320, (150, 152, 158, 255))
    circulo(n * 0.300, (188, 191, 198, 255))
    # miolo escuro entre os raios
    circulo(n * 0.268, (52, 53, 57, 255))

    # raios
    import math
    raios = 5
    for i in range(raios):
        a = i * (2 * math.pi / raios) - math.pi / 2
        larg = 0.052 * n
        r0 = 0.062 * n
        r1 = 0.276 * n
        dx, dy = math.cos(a), math.sin(a)
        px, py = -dy, dx
        pts = [
            (c + dx * r0 + px * larg * 0.55, c + dy * r0 + py * larg * 0.55),
            (c + dx * r1 + px * larg, c + dy * r1 + py * larg),
            (c + dx * r1 - px * larg, c + dy * r1 - py * larg),
            (c + dx * r0 - px * larg * 0.55, c + dy * r0 - py * larg * 0.55),
        ]
        d.polygon(pts, fill=(196, 199, 205, 255))

    # cubo
    circulo(n * 0.082, (168, 170, 176, 255))
    circulo(n * 0.052, (96, 98, 104, 255))

    img = img.resize((LADO, LADO), Image.LANCZOS)
    img.save(SAIDA)
    print("roda gerada:", SAIDA.relative_to(RAIZ), img.size)


if __name__ == "__main__":
    main()

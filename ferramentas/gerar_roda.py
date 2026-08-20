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

    # A carroceria e FOTOGRAFICA. Aro prateado e brilhante com raio vetorial vira
    # adesivo colado por cima. Roda escura e de baixo contraste convive com foto:
    # some na sombra do arco em vez de competir com a lataria.
    circulo(n * 0.500, (10, 10, 11, 255))
    circulo(n * 0.474, (21, 21, 23, 255))
    # ombro e parede lateral do pneu
    circulo(n * 0.408, (15, 15, 17, 255))
    circulo(n * 0.396, (26, 26, 28, 255))

    # aro escuro, so um fio de brilho na borda
    circulo(n * 0.318, (74, 75, 79, 255))
    circulo(n * 0.302, (52, 53, 56, 255))
    circulo(n * 0.276, (30, 30, 33, 255))

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
        d.polygon(pts, fill=(88, 89, 94, 255))

    # cubo
    circulo(n * 0.086, (66, 67, 71, 255))
    circulo(n * 0.050, (38, 39, 42, 255))

    img = img.resize((LADO, LADO), Image.LANCZOS)
    img.save(SAIDA)
    print("roda gerada:", SAIDA.relative_to(RAIZ), img.size)


if __name__ == "__main__":
    main()

# Corpo real (Fase 2)

Gera corpos anatômicos por raça a partir da malha-base e dos alvos de forma do MakeHuman/MPFB2.
Licença dos dados: CC0 (LICENSE.ASSETS.md do MPFB2). Nada pago, nada de Meshy/Mixamo.

1. `git clone --depth 1 https://github.com/makehumancommunity/mpfb2` (fora do projeto)
2. `python3 gerar_corpos.py <mpfb2>/src/mpfb/data /tmp/corpos`  → OBJ por raça e gênero, em metros
3. `pip install bpy` e `python3 prancha.py /tmp/corpos prancha.png m|f`  → frente e perfil

Próximo passo (só depois da aprovação de Robson): ajustar cada corpo à pose de repouso do esqueleto
oficial de 65 ossos e copiar os pesos de pele do corpo atual (sem mexer no esqueleto nem nas 28 animações).

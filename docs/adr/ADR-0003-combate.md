# ADR-0003: Combate híbrido e projeção fantasma

**Status:** aceito (2026-10-23)

- `CombatSim` é puro e clonável. `GhostPlanner.validate_action` é **a mesma** validação usada pela pré-visualização e pela execução.
- O fantasma clona o estado, simula sem dados e devolve custo, chance de acerto, chance de crítico, dano médio e o primeiro passo inválido. Há teste provando que o snapshot não muda.
- Execução: o plano inteiro precisa ser válido no estado congelado. Cada ação é revalidada no estado vivo. Se uma ação ficar inválida, por exemplo porque o alvo caiu, o plano é **interrompido** sem gerar ação gratuita, e o orçamento restante continua disponível.
- Iniciativa: o jogador rola e os inimigos fazem um único teste com o menor modificador (LB p.231). Empates ficam com o maior valor; se persistirem, rola-se de novo.
- Regras aplicadas:
  - Ações padrão/movimento/completa (p.233).
  - Diagonal e terreno difícil custam o dobro (p.238).
  - Flanco +2 e cobertura (p.239).
  - Camuflagem leve na noite ao ar livre e na neblina (p.238).
  - Crítico multiplica só os dados (p.230–231).
  - Sangramento com Constituição CD 15 e morte em min(−10, −PV/2) (p.236).
  - Investida e golpe de misericórdia (p.235).
- Desfechos: vitória, fuga (10 quadrados), captura (só por bandidos; ORIGINAL) e morte (sem proteção narrativa).
- A apresentação reproduz eventos (`COMBAT_MOVED`, `ATTACK_RESOLVED`…) por tags. Animação nunca altera resultado. A velocidade pode ser 1×, 2× ou instantânea, e dá para pular.

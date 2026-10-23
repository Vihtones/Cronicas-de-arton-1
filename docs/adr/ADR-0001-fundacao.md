# ADR-0001 — Decisões de fundação

**Status:** aceito provisoriamente (2026-10-23)

1. **Godot 4.3 stable + GDScript tipado + GL Compatibility.** Maximiza hardware modesto (§3). Revisar ao fixar plataforma (§20.1).
2. **Resolução interna 640×360, escala inteira.** Hipótese para tiles 32×32 / personagens 64×64 (§13). Alternativa a comparar: 480×270 (§20.2).
3. **Domínio em `RefCounted`, sem Node.** Permite testes headless rápidos e cumpre §5.
4. **Um único autoload (`Game`) só de composição.** Evita singleton com lógica (§5).
5. **Persistência JSON atômica** (tmp → valida → backup → rename). SQLite adiado (§20.3).
6. **1 tick = 10 min de jogo; 1 s real = 1 tick** como placeholder (§20.7).
7. **Calendário 30 dias × 12 meses como PLACEHOLDER** até verificar o calendário de Arton no Livro Básico.
8. **Áudio fora do escopo** (§2).

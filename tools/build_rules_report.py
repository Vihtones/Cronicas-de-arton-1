"""Gera docs/REGRAS.md a partir de data/rules/*.json (proveniência de cada regra)."""
import json, pathlib
ROOT = pathlib.Path(__file__).resolve().parent.parent
rows, counts = [], {}
for f in sorted((ROOT / "data" / "rules").glob("*.json")):
    for r in json.loads(f.read_text(encoding="utf-8"))["rules"]:
        counts[r["status"]] = counts.get(r["status"], 0) + 1
        rows.append((f.stem, r))
out = ["# Regras usadas pelo jogo e sua proveniência", "",
       "Gerado por `tools/build_rules_report.py` a partir de `data/rules/`. **Não edite à mão.**", "",
       "Página = página impressa do livro; PDF = página do arquivo PDF, para conferência.", "",
       "| Status | Quantidade |", "|---|---|"] + [f"| {k} | {v} |" for k, v in sorted(counts.items())] + ["",
       "| Arquivo | Regra | Fonte | Pág. | PDF | Status | Nota |", "|---|---|---|---|---|---|---|"]
for stem, r in rows:
    out.append(f"| {stem} | `{r['id']}` | {r['fonte'].split(' (')[0]} | {r['pagina']} | {r.get('pdf_page','')} | {r['status']} | {r.get('nota','')} |")
out += ["", "## Mecânicas ORIGINAL_DO_JOGO e ADAPTADA (fora do catálogo de regras)", "",
"| Mecânica | Onde | Classificação | Configurável |", "|---|---|---|---|",
"| Ficha pronta: Guerreiro humano nível 1 (atributos por compra de pontos) | `CharacterSheet.premade_warrior` | ORIGINAL (montada com regras do LB) | — |",
"| Anti-loop: repetir a mesma abordagem exige outra perícia, valor diferente ou 1 dia | `ExplorationModule.RETRY_TICKS` | ORIGINAL | sim (constante) |",
"| Dormindo: −10 em Percepção para notar furtividade/barulho | `CombatModule` | ADAPTADA | — |",
"| Bandidos capturam quem cai em vez de executar; hienas não | `CombatModule._ai_turn/_check_end` | ORIGINAL | — |",
"| Neblina/tempestade: +5 na CD de percepção ao ar livre | `WeatherModule.perception_cd_mod` | ADAPTADA | `weather_affects_tests` |",
"| Chuva leva NPCs para dentro | `NpcModule.desired_location` | ORIGINAL | desligar módulo clima |",
"| Cripta iluminada por tochas (sem escuridão) | `WeatherModule.env_at` | ORIGINAL | — |",
"| Fuga: 10 quadrados longe de todos os inimigos conscientes | `CombatModule.FLEE_DISTANCE` | ORIGINAL | constante |",
"| Rumores: 35% por hora entre NPCs no mesmo local, confiabilidade ×0,8 | `MemoryModule` | ORIGINAL | constantes |",
"| Incursão da Guarda resolvida em L2 por força relativa | `FactionModule._resolve_raid` | ORIGINAL | — |",
"| Economia agregada com preços limitados a 0,5×–3× | `EconomyModule` | ORIGINAL | `data/world/economy.json` |",
"| Calendário 30 dias × 12 meses, estações por trimestre | `WorldClock`, `WeatherModule.season` | PLACEHOLDER | sim |",
"| 1 tick = 10 min; 2 s reais por tick | `WorldClock`, `Game.settings` | PLACEHOLDER (§20.7) | sim |",
"| Mistério 'O Filho do Moleiro', vila, NPCs, facções, diálogos | `data/world`, `data/dialogue` | ORIGINAL_DO_JOGO | — |",
"| XP de mistério resolvido = ND 1 ('XP alternativo', LB p.326) | `ProgressionModule.MYSTERY_ND` | ORIGINAL | constante |",
"| Fuga conta como empate (½ XP); captura como derrota (¼ XP) | `ProgressionModule` | ADAPTADA | — |",
"| Presets de atributos e perícias padrão por classe | `CharacterBuilder` | ORIGINAL (dentro das regras) | — |",
"| Alcance médio de magia = 20 quadrados | `GhostPlanner` (cast) | PLACEHOLDER (alcance.metros pendente) | — |",
"| Relento com saco de dormir = condição normal | `StateModule.rest_quality` | ADAPTADA | — |",
"| Rotas, distâncias e risco de emboscada (5%/20% por dia) | `TravelModule` | ORIGINAL | constantes |",
"| Domínio: renda, moral, segurança, conselheiros | `DomainModule` | ORIGINAL | constantes |",
"| Casais, chance de nascimento 15%/ano; herança ao parente vivo mais velho; herdeiro com ½ do ouro | `LineageModule` | ORIGINAL | constantes |",
"| Aventureiros NPC: missões 25%/dia, ND sorteado, XP pela regra do LB | `AdventurersModule` | ORIGINAL (XP: LB) | constantes |",
"| Matilha: comida, caça por estação, ataques a ovelhas, crescimento até 4 | `FaunaModule` | ORIGINAL | constantes |",
"| Investigação criminal: Investigação +4 da capitã vs CD 20 − pistas | `CrimeModule._investigate` | PLACEHOLDER | — |",
"| Preconceito individual: −10 de reputação e +20% no preço até 3 memórias | `MemoryModule.bias`, `EconomyModule.price` | ORIGINAL | traço do NPC |",
"| Vinhetas do diretor de ritmo | `PacingModule` | ORIGINAL | — |"]
(ROOT / "docs" / "REGRAS.md").write_text("\n".join(out) + "\n", encoding="utf-8")
print("regras", len(rows), counts)

class_name Narrator
extends RefCounted
## Converte eventos em texto para o registro. Só narra o que o jogador PERCEBE:
## eventos com o jogador como ator ou no local onde ele está. Nunca revela o resto.

const SKILL_NAMES := {"percepcao": "Percepção", "investigacao": "Investigação", "sobrevivencia": "Sobrevivência", "intuicao": "Intuição",
	"intimidacao": "Intimidação", "diplomacia": "Diplomacia", "furtividade": "Furtividade", "ladinagem": "Ladinagem", "luta": "Luta"}


static func _name(id: String) -> String:
	if id == "player": return "Você"
	var n := Game.db.npc_def(id)
	if not n.is_empty(): return n.name
	var c := Game.db.creature_def(id)
	if not c.is_empty(): return c.name
	return id


static func _check(c: Dictionary) -> String:
	if c.is_empty() or not c.get("allowed", true): return ""
	return " (%s %d + %d = %d vs CD %d %s)" % [SKILL_NAMES.get(c.get("skill", ""), str(c.get("skill", "")).capitalize()), c.d20, c.mod, c.total, c.cd, "✔" if c.success else "✘"]


static func line(e: GameEvent) -> String:
	var p := e.payload
	var mine := e.actor_ids.has("player")
	match e.event_type:
		"TARGET_INSPECTED": return "%s%s" % [p.text, _check(p.check)]
		"FACT_REVEALED":
			var t: String = Game.db.fact_text(p.fact)
			return "[Diário] " + t if t != "" else ""
		"OBJECT_OPENED": return "Aberto: %s." % Game.db.object_def(p.object).name if mine else ""
		"OBJECT_CLOSED": return "Fechado." if mine else ""
		"OBJECT_UNLOCKED": return "Destrancado." if mine else ""
		"OBJECT_DAMAGED": return ("Golpe na %s: %d de dano (resta %d PV)." % [Game.db.object_def(p.object).name, p.damage, p.pv]) if p.hit else "O golpe resvala na madeira."
		"OBJECT_BROKEN": return "%s cede com um estrondo!" % Game.db.object_def(p.object).name
		"ITEM_GAINED": return "Obtido: %s." % Game.db.items.get(p.item, {}).get("name", p.item) if mine else ""
		"ITEM_LOST": return "Entregue: %s." % Game.db.items.get(p.item, {}).get("name", p.item)
		"GOLD_CHANGED": return ("%+d tibares (%s)." % [p.delta, p.get("reason", "")]) if p.delta != 0 else ""
		"PLAYER_TELEPORTED": return "Você desce os degraus." if p.via == "escada_ruina" else "Você sobe à superfície."
		"CHECK_FAILED": return "Não funcionou.%s" % _check(p.check)
		"STANCE_CHANGED": return "Você se move furtivamente." if p.sneak else "Você volta a andar normalmente."
		"STEALTH_CHECK": return "Furtividade %d vs Percepção %d: %s" % [p.player_total, p.enemy_total, "não perceberam você." if p.success else "você foi notado!"]
		"NOISE_UNHEARD": return "Ninguém acorda. Por enquanto."
		"NOISE_HEARD": return "O barulho ecoa pela cripta. Passos apressados vêm em sua direção!"
		"COMBAT_STARTED":
			var s := "COMBATE! Iniciativa: você %d, inimigos %d." % [p.initiative.player, p.initiative.enemies]
			if p.enemies_surprised: s += " Os inimigos foram surpreendidos!"
			return s
		"TURN_SKIPPED": return "%s está surpreendido e não age." % _name(p.actor)
		"ATTACK_RESOLVED":
			if p.get("spell", false):
				return "%s lança %s em %s: %d de dano (acerto automático)%s." % [_name(p.attacker), p.weapon, _name(p.target), p.damage, " — cai!" if p.pv_after <= 0 else ""]
			var who := _name(p.attacker)
			var tgt := _name(p.target)
			var res := ""
			if p.hit:
				res = "acerta%s: %d de dano" % [" CRÍTICO" if p.crit else "", p.damage]
				if p.pv_after <= 0: res += " — %s cai!" % tgt
			else:
				res = "falha (camuflagem)" if p.camo_roll > 0 and p.total >= p.defense else "erra"
			return "%s ataca %s com %s: %d+%d=%d vs Def %d, %s." % [who, tgt, p.weapon, p.d20, p.mod, p.total, p.defense, res]
		"COUP_DE_GRACE": return "%s desfere um golpe de misericórdia em %s (%d de dano)%s." % [_name(p.attacker), _name(p.target), p.damage, " — fatal" if p.dies else ""]
		"BLEED_CHECK": return "%s sangra: Con %d vs CD 15 — %s" % [_name(p.actor), p.check.total, "estabiliza." if p.check.success else ("perde %d PV%s." % [p.lost, " e morre" if p.dead else ""])]
		"PLAN_INTERRUPTED": return "Plano interrompido: %s. Replaneje as ações restantes." % p.reason
		"STOOD_UP": return "%s se levanta." % _name(p.actor)
		"COMBAT_ENDED":
			return {"vitoria": "O combate termina. Você venceu.", "fuga": "Você escapou.", "captura": "Tudo escurece...", "morte": ""}.get(p.outcome, "")
		"PLAYER_ROBBED": return "Você acorda na beira da estrada, dolorido e de bolsos vazios."
		"PLAYER_CAPTURED": return "Você acorda numa cela fria, sem a bolsa. Ainda vivo."
		"PLAYER_DIED": return "Você morreu."
		"CREATURE_DEFEATED": return ("%s foi derrotado." % p.name) if p.get("by", "") == "player" else ""
		"NPC_RESCUED": return "%s está livre!" % _name(p.npc) if p.rescuer == "player" else ""
		"MYSTERY_RESOLVED": return "[Mistério resolvido] %s" % Game.db.mystery.title if p.by == "player" else ""
		"WEATHER_CHANGED":
			if Game.db.zone_at(Game.player_tile()) == "cripta": return ""
			return {"chuva": "Começa a chover.", "tempestade": "Uma tempestade desaba.", "neblina": "Uma neblina baixa cobre o chão.",
				"limpo": "O céu abre.", "nublado": "Nuvens cobrem o céu."}.get(p.to, "")
		"RESTED": return "Você descansa %dh (condição %s): +%d PV/PM." % [p.hours, p.quality, p.recovered]
		"CRIME_COMMITTED": return ("Você pega a mercadoria... e %d pessoa(s) viram." % p.witnesses.size()) if not p.witnesses.is_empty() else "Você pega a mercadoria. Ninguém parece notar."
		"WARRANT_ISSUED": return "Você sente olhares: a Guarda soube do que você fez (multa T$ %d)." % p.fine
		"FINE_PAID": return "Multa paga."
		"ITEM_BOUGHT": return "Comprado: %s por T$ %d." % [Game.db.items[p.item].name, p.price]
		"DIZIMO_RETURNED": return "O dízimo volta ao templo." if p.get("actor", "") == "player" else ""
		"BECOME_DEVOTEE": return "Você agora é devoto(a) de %s." % p.god
		"OBLIGATION_VIOLATED": return "Você causou dano letal. Seus votos a %s foram quebrados." % p.god
		"DIALOGUE_TEST": return "Teste%s" % _check(p.check)
		"XP_GAINED":
			var parts: Array = []
			for b in p.get("breakdown", []):
				parts.append(("%s %+d%%" % [b[0], int(round(float(b[1]) * 100))]) if float(b[1]) != 0.0 else str(b[0]))
			return "+%d XP (%s)%s. Total: %d." % [p.amount, p.reason, (" — " + "; ".join(parts)) if not parts.is_empty() else "", p.total]
		"POWER_CHOSEN": return "Poder adquirido: %s%s." % [str(p.power).replace("_", " "), (" (" + p.option + ")") if p.option != "" else ""]
		"MANEUVER_RESOLVED": return "%s tenta derrubar %s: %d vs %d — %s" % [_name(p.attacker), _name(p.target), p.attacker_total, p.target_total, "caído!" if p.success else "resiste."]
		"LEVEL_UP": return "NÍVEL %d! +%d PV, +%d PM. Escolha um poder no diário (J)." % [p.level, p.pv_gain, p.pm_gain]
		"SPELL_FAILED": return "%s perde a magia: %s CD %d (%s) — tirou %d." % [_name(p.caster), "Vontade" if p.check == "vontade" else "Misticismo", p.cd, p.reason, p.total]
		"BUFF_APPLIED": return "Armadura Arcana: +%d na Defesa até o fim da cena." % p.defense if p.buff == "armadura_arcana" else ""
		"SPELL_CAST": return "Magia: %s (−%d PM, resta %d)." % [str(p.spell).replace("_", " ").capitalize(), p.pm_cost, p.pm_after] if p.caster == "player" else ""
		"HEALED": return "%s recupera %d PV." % [_name(p.target), p.amount]
		"EQUIPPED": return "Equipado: %s (Defesa %d)." % [Game.db.items.get(p.item, {}).get("name", p.item), p.defense]
		"TRAVEL_STARTED": return "Você parte: %d km, cerca de %.1f dias de marcha." % [p.km, p.days]
		"AMBUSH_PERCEPTION": return "Emboscada! Percepção %d vs Furtividade %d: %s" % [p.player_total, p.enemy_total, "eles te pegaram desprevenido!" if p.player_surprised else "você os viu a tempo."]
		"TRAVEL_AMBUSH":
			if p.get("tactical", false): return "Salteadores saltam do mato na saída da estrada!"
			return "Emboscada no dia %d! −%d PV, −T$ %d." % [p.day, p.pv_lost, p.gold_lost]
		"JOURNEY_CHALLENGE": return "Jornada pelos ermos: %d sucessos, %d falhas." % [p.successes, p.failures]
		"TRAVEL_ARRIVED": return "Você chega a %s." % {"valkaria": "Valkaria", "vila": "Vila Alvorada", "ermos_norte": "os Ermos do Norte"}.get(p.region, p.region)
		"GRANT_DOMAIN": return "Você agora administra %s. (J > Domínio)" % p.domain
		"DOMAIN_WEEK": return "Domínio, semana %d: renda %d, custos %d, tesouro %d, moral %d, segurança %d.%s" % [p.week, p.income, p.upkeep, p.treasury, p.morale, p.security, (" " + p.event) if p.event != "" else ""]
		"DOMAIN_UNREST": return "Há murmúrios contra os impostos no moinho."
		"NPC_DIED": return "%s morreu (%s, %d anos)." % [_name(p.npc), p.cause, p.age]
		"INHERITANCE": return "%s herda a casa e as economias de %s." % [_name(p.to), _name(p.from)]
		"NPC_BORN": return "Nasce uma criança na família %s." % str(p.family).capitalize()
		"HERO_SUCCEEDED": return "%s assume o legado de %s. O mundo lembra do outro, não de você." % [p.new_name, p.previous_name]
		"SHEEP_KILLED":
			return "Gritos de Fenna na estrada: uma ovelha morta." if Game.db.zone_at(Game.player_tile()) != "cripta" else ""
		"PACK_RELOCATED": return ""
		"CRIME_INVESTIGATED": return ""
		"AMBIENT_VIGNETTE": return p.text
		"OBLIGATION_VIOLATED": return "Você quebrou os votos a %s." % p.god
		"TRADE_DELIVERED":
			return "Saria chega com mercadorias de Valkaria." if Game.db.location_at(Game.player_tile()) in ["mercado", "taverna", "praca"] else ""
	return ""

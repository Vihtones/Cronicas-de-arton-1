class_name DomainModule
extends WorldModule
## Administração de domínio (§11): decisões de alto nível, conselheiros e delegação.
## Protótipo: o Moinho Brandt e as terras vizinhas como pequeno domínio. Turno semanal.
## Tudo ORIGINAL_DO_JOGO.

const TAX := {"baixo": 0.05, "medio": 0.1, "alto": 0.2}
const ADVISORS := {
	"otto": {"area": "producao", "competencia": 2},
	"elsa": {"area": "seguranca", "competencia": 3},
	"orin": {"area": "administracao", "competencia": 2},
}

var owned := false
var domain_name := "Moinho Brandt"
var treasury := 0
var morale := 60          # 0..100
var security := 50        # 0..100
var policy := {"imposto": "medio", "patrulha": false, "celeiro": false}
var delegated := false
var reports: Array[Dictionary] = []


func module_id() -> String: return "domain"
func handled_commands() -> PackedStringArray: return PackedStringArray(["SetPolicy", "Delegate", "GrantDomain"])
func subscribed_events() -> PackedStringArray: return PackedStringArray(["GRANT_DOMAIN"])


func validate(cmd: GameCommand) -> PackedStringArray:
	match cmd.type:
		"GrantDomain":
			if owned: return PackedStringArray(["já possui o domínio"])
		"SetPolicy":
			if not owned: return PackedStringArray(["você não administra nada"])
			var k: String = cmd.payload.get("key", "")
			if not policy.has(k): return PackedStringArray(["política desconhecida"])
			if k == "imposto" and not TAX.has(cmd.payload.get("value", "")): return PackedStringArray(["valor inválido"])
		"Delegate":
			if not owned: return PackedStringArray(["você não administra nada"])
	return PackedStringArray()


func execute(cmd: GameCommand) -> Array:
	match cmd.type:
		"GrantDomain":
			return [fact("GRANT_DOMAIN", {"domain": domain_name, "by": cmd.payload.get("by", "orin")}, ["player"])]
		"SetPolicy":
			policy[cmd.payload.key] = cmd.payload.value
			return [fact("POLICY_SET", {"key": cmd.payload.key, "value": cmd.payload.value}, ["player"])]
		"Delegate":
			delegated = bool(cmd.payload.get("on", true))
			return [fact("DOMAIN_DELEGATED", {"on": delegated}, ["player"])]
	return []


func on_event(e: GameEvent) -> Array:
	if e.event_type == "GRANT_DOMAIN":
		owned = true
		treasury = 10
	return []


## Conselheiro decide quando delegado (heurística legível).
func _advisor_policy() -> void:
	if morale < 40:
		policy.imposto = "baixo"
	elif treasury < 10:
		policy.imposto = "medio"
	policy.patrulha = security < 40 and treasury >= 5
	policy.celeiro = morale > 50 and treasury >= 15


func on_tick(tick: int) -> Array:
	if not owned or tick % (7 * 24 * 60 / world.clock.tick_minutes) != 0:
		return []
	if delegated:
		_advisor_policy()
	var eco = world.module("economy")
	var food := 120
	if eco != null:
		food = int(eco.regions.vila.stock.get("comida", 120))
	var production := 40 + ADVISORS.otto.competencia * 5
	var income := int(round(production * TAX[policy.imposto] * 10))
	var upkeep := (6 if policy.patrulha else 0) + (8 if policy.celeiro else 0)
	treasury += income - upkeep
	morale += {"baixo": 4, "medio": 0, "alto": -6}[policy.imposto] + (3 if policy.celeiro else 0) - (5 if food < 60 else 0)
	security += (8 if policy.patrulha else -3)
	var w = world.module("weather")
	var event := ""
	if w != null and w.region.surface == "seco" and world.rng.stream("world").randf() < 0.1:
		event = "seca leve: produção menor"
		treasury -= 3
	if security < 30 and world.rng.stream("world").randf() < 0.3:
		event = "furto no celeiro"
		treasury -= 5
		morale -= 3
	morale = clampi(morale, 0, 100)
	security = clampi(security, 0, 100)
	var food_out := production / 2 + (10 if policy.celeiro else 0)  # sacas de farinha para o estoque da vila
	var rep := {"week": reports.size() + 1, "food_out": food_out, "income": income, "upkeep": upkeep, "treasury": treasury, "morale": morale,
		"security": security, "policy": policy.duplicate(), "event": event, "delegated": delegated}
	reports.append(rep)
	var out: Array = [fact("DOMAIN_WEEK", rep, ["player"])]
	if policy.imposto == "alto" and morale < 35:
		out.append(fact("DOMAIN_UNREST", {"morale": morale, "location": "moinho", "witnesses": ["otto", "hilda"]}, ["player"]))
	return out


func to_dict() -> Dictionary:
	return {"owned": owned, "treasury": treasury, "morale": morale, "security": security, "policy": policy.duplicate(),
		"delegated": delegated, "reports": reports.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	owned = bool(d.get("owned", false)); treasury = int(d.get("treasury", 0)); morale = int(d.get("morale", 60))
	security = int(d.get("security", 50)); policy = d.get("policy", policy).duplicate(); delegated = bool(d.get("delegated", false))
	reports.clear()
	for r in d.get("reports", []):
		reports.append(r)

class_name TormentaModule
extends WorldModule
## Corrupção persistente da Tormenta (Arton Viva, Fase 7). Homebrew abstrato, não regra oficial de área.
## Três variáveis separadas (§14.2):
## - pressão: só cresce com incidentes sobrenaturais (MAGIC_INCIDENT). Pobreza, guerra e instabilidade não geram pressão.
## - corrupção efetiva: acumula enquanto houver pressão; não some sozinha, por isso as consequências persistem.
## - contenção: ação da Guarda (ContainTormenta), que gasta soldados e reduz a pressão.
## Estágios: 0 estabilidade, 1 presságios, 2 infiltração, 3 crise, 4 devastação. Cada mudança sai como fato.
## A economia reage ao estágio (TORMENTA_DAY); sem incidente, o mundo segue sem a ameaça.

const PRESSURE_DECAY := 2.0       # pressão que se dissipa por dia sem novos incidentes
const CORRUPTION_RATE := 0.05     # corrupção ganha por dia, por ponto de pressão
const CONTAIN_RELIEF := 20.0      # pressão removida por contenção
const CONTAIN_COST := 1           # soldados gastos por contenção
const STAGE_AT := [0.0, 1.0, 20.0, 50.0, 80.0]   # corrupção mínima de cada estágio (0 a 4)

var pressure: float = 0.0
var corruption: float = 0.0
var stage: int = 0
var last_day := -1


func module_id() -> String: return "tormenta"
func handled_commands() -> PackedStringArray: return PackedStringArray(["ContainTormenta"])
func subscribed_events() -> PackedStringArray: return PackedStringArray(["MAGIC_INCIDENT", "TIME_ADVANCED"])


func soldiers() -> int:
	var f = world.module("factions")
	if f == null:
		return 0
	return int(f.resources.get("guarda_vila", {}).get("soldados", 0))


func validate(cmd: GameCommand) -> PackedStringArray:
	if pressure <= 0.0:
		return PackedStringArray(["não há pressão sobrenatural para conter"])
	if soldiers() < CONTAIN_COST:
		return PackedStringArray(["a Guarda não tem soldados para conter a ameaça"])
	return PackedStringArray()


func execute(_cmd: GameCommand) -> Array:
	pressure = maxf(0.0, pressure - CONTAIN_RELIEF)
	# os soldados são gastos pela facção, que consome o próprio fato
	return [fact("TORMENTA_CONTAINED", {"pressure": pressure, "soldiers_spent": CONTAIN_COST, "faction": "guarda_vila"})]


func on_event(e: GameEvent) -> Array:
	if e.event_type == "MAGIC_INCIDENT":
		pressure = minf(100.0, pressure + float(e.payload.get("pressure", 10)))
		return []
	if e.event_type == "TIME_ADVANCED" and world.day_index() != last_day:
		last_day = world.day_index()
		return _daily()
	return []


func _daily() -> Array:
	var out: Array = []
	if pressure > 0.0:
		corruption = minf(100.0, corruption + pressure * CORRUPTION_RATE)
	pressure = maxf(0.0, pressure - PRESSURE_DECAY)
	var novo := _stage_for(corruption)
	if novo != stage:
		stage = novo
		out.append(fact("TORMENTA_STAGE_CHANGED", {"stage": stage, "corruption": snappedf(corruption, 0.1)}))
	if stage > 0:
		out.append(fact("TORMENTA_DAY", {"stage": stage}))
	return out


func _stage_for(c: float) -> int:
	var s := 0
	for i in STAGE_AT.size():
		if c >= float(STAGE_AT[i]) and (i == 0 or c > 0.0):
			s = i
	return s


func to_dict() -> Dictionary:
	return {"pressure": pressure, "corruption": corruption, "stage": stage, "last_day": last_day}


func from_dict(d: Dictionary) -> void:
	pressure = float(d.get("pressure", 0.0))
	corruption = float(d.get("corruption", 0.0))
	stage = int(d.get("stage", 0))
	last_day = int(d.get("last_day", -1))

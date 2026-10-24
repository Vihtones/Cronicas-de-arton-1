class_name WorldFactory
extends RefCounted
## Monta o mundo com todos os módulos. Opcionais podem ser desligados por config
## sem impedir o boot (§5, §16).

const OPTIONAL := ["weather", "memory", "factions", "crime", "economy", "region_sim", "religion",
	"progression", "items", "travel", "domain", "lineage", "adventurers", "fauna", "pacing"]


static func create(p_seed: int = 20261023, disabled: Array = [], rules: RuleRegistry = null, db: ContentDB = null) -> WorldState:
	var r := rules if rules != null else RuleRegistry.load_default()
	var d := db if db != null else ContentDB.load_default()
	var w := WorldState.new(r, d)
	w.rng.reseed(p_seed)
	w.player.position = d.tile_to_world(Vector2i(int(d.map.player_start[0]), int(d.map.player_start[1])))
	# Ordem importa para listeners: estado primeiro; memória antes de crime.
	for m in [StateModule.new(), ObjectsModule.new(), NpcModule.new(), WeatherModule.new(), ExplorationModule.new(),
			MemoryModule.new(), FactionModule.new(), CombatModule.new(), DialogueModule.new(), CrimeModule.new(),
			EconomyModule.new(), RegionSimModule.new(), ReligionModule.new(), ProgressionModule.new(), ItemsModule.new(),
			TravelModule.new(), DomainModule.new(), LineageModule.new(), AdventurersModule.new(), FaunaModule.new(), PacingModule.new()]:
		w.register(m)
	for id in disabled:
		if OPTIONAL.has(id):
			w.set_module_enabled(id, false)
	# Estado inicial materializado na criação (from_snapshot substitui depois, se houver save)
	for id in w.modules:
		if w.modules[id].has_method("_ensure"):
			w.modules[id]._ensure()
	return w

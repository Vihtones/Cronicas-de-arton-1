class_name HomebrewModule
extends WorldModule
## Homebrews de jogabilidade (Arton Viva, Fase 8). ORIGINAL_DO_JOGO, opcionais e identificáveis.
## Cada regra tem id, nome, versão, justificativa, dependências e conflitos. Nenhuma altera dados oficiais T20.
## - Parceiro T20 (mecânica oficial de apoio) e Party Tática (homebrew de coordenação) não podem estar
##   ligados juntos: não se somam benefícios duplicados.
## - Ligar uma regra exige suas dependências; desligar não apaga nada do que ela já produziu.
## O padrão é tudo desligado: o jogo sem homebrew é o jogo T20 básico.

const RULES := {
	"interacao_combate": {"name": "Interação contextual em combate", "version": "1.0", "requires": [], "conflicts": [],
		"justification": "Empurrões, desarmes e cobertura com os limites de T20."},
	"familiaridade_pratica": {"name": "Familiaridade prática", "version": "1.0", "requires": [], "conflicts": [],
		"justification": "Experiência limitada em atividades profissionais e sociais; não substitui o nível."},
	"parceiro_t20": {"name": "Parceiro T20", "version": "1.0", "requires": [], "conflicts": ["party_tatica"],
		"justification": "Apoio segundo as mecânicas oficiais de parceiros."},
	"party_tatica": {"name": "Party Tática", "version": "1.0", "requires": ["companheiros"], "conflicts": ["parceiro_t20"],
		"justification": "Posicionamento, ordens e combate coordenado (Mestre §11.3)."},
	"companheiros": {"name": "Companheiros táticos", "version": "1.0", "requires": [], "conflicts": [],
		"justification": "Recrutamento e ordens do grupo (módulo de party)."},
	"ferimentos_narrativos": {"name": "Ferimentos narrativos", "version": "1.0", "requires": [], "conflicts": [],
		"justification": "Ferimentos graves geram efeitos temporários e recuperáveis, sem penalidade permanente."},
	"vida_social": {"name": "Vida social e instituições", "version": "1.0", "requires": [], "conflicts": [],
		"justification": "Contratos, negociações e favores ampliados."},
}

var ligadas: Dictionary = {}  # id -> true


func module_id() -> String: return "homebrew"
func handled_commands() -> PackedStringArray: return PackedStringArray(["SetHomebrew"])


func is_on(id: String) -> bool:
	return bool(ligadas.get(id, false))


func validate(cmd: GameCommand) -> PackedStringArray:
	var id := str(cmd.payload.get("id", ""))
	if not RULES.has(id):
		return PackedStringArray(["homebrew desconhecido"])
	if not bool(cmd.payload.get("on", true)):
		return PackedStringArray()
	var rule: Dictionary = RULES[id]
	var errs := PackedStringArray()
	for dep in rule.requires:
		if not is_on(dep):
			errs.append("depende de %s" % RULES[dep].name)
	for c in rule.conflicts:
		if is_on(c):
			errs.append("conflita com %s" % RULES[c].name)
	return errs


func execute(cmd: GameCommand) -> Array:
	var id := str(cmd.payload.id)
	var on := bool(cmd.payload.get("on", true))
	if on:
		ligadas[id] = true
	else:
		ligadas.erase(id)
	return [fact("HOMEBREW_SET", {"id": id, "on": on, "version": RULES[id].version})]


func to_dict() -> Dictionary: return {"ligadas": ligadas.duplicate(true)}


func from_dict(d: Dictionary) -> void: ligadas = d.get("ligadas", {}).duplicate(true)

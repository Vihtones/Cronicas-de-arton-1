class_name FumbleTable
extends RefCounted
## Falha crítica (ataque que erra com 1 natural): uma de seis consequências, escolhida com 1d6.
## ADAPTADA: a tabela oficial não está nos PDFs lidos. Números e efeitos ficam para revisão no balanceamento.

const OUTCOMES := [
	{"id": "tropeca", "titulo": "TROPEÇO!", "texto": "tropeça no próprio pé e vai ao chão"},
	{"id": "arma_escapa", "titulo": "A ARMA VOA!", "texto": "a arma escapa da mão e a ação padrão se perde"},
	{"id": "parede", "titulo": "CONTRA A PAREDE!", "texto": "o golpe volta e bate na própria guarda"},
	{"id": "desequilibrio", "titulo": "DESEQUILÍBRIO!", "texto": "perde o equilíbrio e o passo de movimento junto"},
	{"id": "dedo_cortado", "titulo": "AI!", "texto": "corta o dedo na própria lâmina"},
	{"id": "grito", "titulo": "PAUSA DRAMÁTICA!", "texto": "a arma gira no ar, e todo mundo para para ver"},
]


## Escolhe a consequência com um d6 (1 a 6 na ordem de OUTCOMES).
static func pick(rng: RngStreams) -> Dictionary:
	return OUTCOMES[rng.roll("combat", 1, 6)[0] - 1]


## Aplica a consequência ao atacante e devolve as tags de dano geradas.
static func apply(sim: CombatSim, actor: String, outcome: Dictionary) -> PackedStringArray:
	var tags := PackedStringArray()
	match str(outcome.id):
		"tropeca":
			sim.c(actor).sheet.add_condition("caido")
		"arma_escapa":
			sim.spend("padrao")
		"parede", "dedo_cortado":
			tags.append_array(sim.apply_damage(actor, 1))
		"desequilibrio":
			sim.spend("movimento")
	return tags

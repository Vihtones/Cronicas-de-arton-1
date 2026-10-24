class_name Biography
extends RefCounted
## Biografia prévia gerada como HISTÓRICO RESUMIDO consistente (§8), nunca simulada
## dia a dia. Determinística por (seed do mundo, id do NPC). ORIGINAL_DO_JOGO.

const ORIGINS := ["nasceu aqui mesmo em Alvorada", "veio de uma fazenda ao sul", "chegou de Valkaria ainda jovem", "cresceu numa aldeia de pescadores"]
const YOUTH := ["sobreviveu a um inverno de fome", "perdeu um irmão para uma febre", "aprendeu o ofício com um tio severo",
	"fugiu de casa e voltou um ano depois", "viu a Guarda expulsar salteadores da estrada"]
const ADULT := ["sonha em juntar dinheiro", "guarda uma mágoa antiga de um vizinho", "é devoto discreto", "tem medo da floresta à noite",
	"ainda se lembra de quando a torre não era ruína"]


static func for_npc(d: Dictionary, world_seed: int) -> String:
	var h := absi(hash([world_seed, d.get("id", "")]))
	var age := int(d.get("age", 30))
	var parts: Array = []
	parts.append("%s %s" % [d.get("name", "?").get_slice(" ", 0), ORIGINS[h % ORIGINS.size()]])
	if age >= 14:
		parts.append(YOUTH[(h / 7) % YOUTH.size()])
	if age >= 20:
		parts.append("trabalha como %s" % d.get("profession", "trabalhador"))
	if age >= 25:
		parts.append(ADULT[(h / 31) % ADULT.size()])
	if d.get("devotion", "") != "":
		parts.append("e reza a %s" % d.devotion)
	return ", ".join(parts) + "."

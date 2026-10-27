extends RefCounted
## Habilidades de classe com efeito mecânico no jogo. Só o que está aqui altera regras;
## o restante da habilidade continua no catálogo (classe.<id>.habilidades) como texto.

## Fúria do bárbaro (catálogo classe.barbaro): +2 em ataques e dano corpo a corpo;
## sobe para +3 no 6º nível, +4 no 11º e +5 no 16º. Simplificação: vale o tempo todo em combate,
## sem o custo de ativar e a fadiga da fúria real.
## Fúria Titânica (20º nível): o bônus da fúria é dobrado.
static func furia_bonus(sh: CharacterSheet) -> int:
	if sh == null or sh.class_id != "barbaro":
		return 0
	var base := 2
	if sh.level >= 16:
		base = 5
	elif sh.level >= 11:
		base = 4
	elif sh.level >= 6:
		base = 3
	return base * 2 if sh.level >= 20 else base


## Instinto Selvagem (LB p.42): +1 em rolagens de dano a partir do 3º nível, +1 a cada seis níveis.
static func instinto_bonus(sh: CharacterSheet) -> int:
	if sh == null or sh.class_id != "barbaro" or sh.level < 3:
		return 0
	return 1 + (sh.level - 3) / 6


## Instinto Selvagem também dá o bônus em Percepção e Reflexos.
static func instinto_pericia(sh: CharacterSheet, skill: String) -> int:
	if skill != "percepcao" and skill != "reflexos":
		return 0
	return instinto_bonus(sh)


## Golpe Divino do paladino (LB p.82): 2 PM, soma o Carisma no ataque e +1d8 no dano corpo a corpo.
## A cada quatro níveis, +1 PM por +1d8 adicional (até level / 4 vezes).
static func golpe_divino_disponivel(sh: CharacterSheet) -> bool:
	return sh != null and sh.class_id == "paladino"


static func golpe_passos_max(sh: CharacterSheet) -> int:
	return sh.level / 4 if sh != null else 0


## Redução de Dano do bárbaro (LB p.42): RD 2 a partir do 5º nível, +2 a cada três níveis, até 10 no 17º.
static func reducao_dano(sh: CharacterSheet) -> int:
	if sh == null or sh.class_id != "barbaro" or sh.level < 5:
		return 0
	return mini(10, 2 + 2 * ((sh.level - 5) / 3))

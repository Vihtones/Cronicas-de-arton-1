extends RefCounted
## Habilidades de classe com efeito mecânico no jogo. Só o que está aqui altera regras;
## o restante da habilidade continua no catálogo (classe.<id>.habilidades) como texto.

## Fúria do bárbaro (catálogo classe.barbaro): +2 em ataques e dano corpo a corpo;
## sobe para +3 no 6º nível, +4 no 11º e +5 no 16º. Simplificação: vale o tempo todo em combate,
## sem o custo de ativar e a fadiga da fúria real.
static func furia_bonus(sh: CharacterSheet) -> int:
	if sh == null or sh.class_id != "barbaro":
		return 0
	if sh.level >= 16:
		return 5
	if sh.level >= 11:
		return 4
	if sh.level >= 6:
		return 3
	return 2

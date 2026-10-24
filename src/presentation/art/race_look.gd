class_name RaceLook
extends RefCounted
## Visual PROVISÓRIO por raça (o usuário pediu modelos simples até a arte final passar pelo governador):
## só tinta e escala sobre o sprite-base. Nada aqui é arte aprovada; serve para distinguir raças em jogo.

const LOOK := {
	"humano": {"tint": Color(1, 1, 1), "scale": 1.0},
	"anao": {"tint": Color(1.0, 0.9, 0.82), "scale": 0.9},
	"dahllan": {"tint": Color(0.78, 1.0, 0.72), "scale": 1.0},
	"elfo": {"tint": Color(0.95, 0.97, 1.0), "scale": 1.05},
	"goblin": {"tint": Color(0.7, 0.9, 0.55), "scale": 0.8},
	"lefou": {"tint": Color(1.0, 0.72, 0.72), "scale": 1.0},
	"minotauro": {"tint": Color(0.82, 0.66, 0.52), "scale": 1.15},
	"qareen": {"tint": Color(1.0, 0.86, 0.6), "scale": 1.0},
	"golem": {"tint": Color(0.72, 0.72, 0.78), "scale": 1.1},
	"hynne": {"tint": Color(1.0, 0.95, 0.85), "scale": 0.78},
	"kliren": {"tint": Color(0.9, 0.85, 1.0), "scale": 0.92},
	"medusa": {"tint": Color(0.7, 0.95, 0.75), "scale": 1.0},
	"osteon": {"tint": Color(0.95, 0.93, 0.86), "scale": 1.0},
	"sereia": {"tint": Color(0.65, 0.9, 1.0), "scale": 1.0},
	"silfide": {"tint": Color(0.95, 0.85, 1.0), "scale": 0.65},
	"aggelus": {"tint": Color(1.0, 1.0, 0.85), "scale": 1.0},
	"sulfure": {"tint": Color(0.75, 0.68, 0.9), "scale": 1.0},
	"trog": {"tint": Color(0.6, 0.78, 0.55), "scale": 1.05},
}


static func of(race: String) -> Dictionary:
	return LOOK.get(race, LOOK.humano)

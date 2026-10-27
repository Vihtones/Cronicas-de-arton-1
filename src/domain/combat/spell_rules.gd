extends RefCounted
## Regras de magias já completas no jogo. Só aparece para o jogador (e só pode ser escolhida) a magia
## com todos os aprimoramentos implementados. COMPLETAS guarda, por magia, os índices de aprimoramento
## (ordem do catálogo `magia.<id>.aprimoramentos`) que já têm efeito.

const COMPLETAS := {
	"perdicao": {"aprimoramentos": [0]},
}


## Círculo máximo que o conjurador pode lançar. Usa a tabela de conjuração da classe (ex.: clérigo: 2º no 5º nível).
static func circulo_maximo(sheet: CharacterSheet, rules: RuleRegistry) -> int:
	var magia: Dictionary = rules.value("classe." + sheet.class_id, {}).get("magia", {})
	var circulos: Dictionary = magia.get("circulos", {})
	if circulos.is_empty():
		return 1 + maxi(0, (sheet.level - 1) / 4)   # arcanista e demais: mesmo ritmo do raio arcano
	var best := 1
	for c in circulos:
		if sheet.level >= int(circulos[c]):
			best = maxi(best, int(c))
	return best


static func aprimoramentos_validos(sp_id: String, idx: Array) -> bool:
	if not COMPLETAS.has(sp_id):
		return idx.is_empty()
	var permitidos: Array = COMPLETAS[sp_id].aprimoramentos
	for i in idx:
		if not permitidos.has(int(i)):
			return false
	return true


static func custo_aprimoramentos(rules: RuleRegistry, sp_id: String, idx: Array) -> int:
	var lista: Array = rules.value("magia." + sp_id, {}).get("aprimoramentos", [])
	var total := 0
	for i in idx:
		if int(i) >= 0 and int(i) < lista.size():   # índice inválido é recusado na validação, não aqui
			total += int(lista[int(i)].pm)
	return total


## Perdição (divina 1): –1 em ataques e dano; +2 PM: –1 a mais (limite = círculo máximo do conjurador).
static func penalidade_perdicao(sheet: CharacterSheet, rules: RuleRegistry, idx: Array) -> int:
	var p := 1 + (1 if idx.has(0) else 0)
	return mini(p, circulo_maximo(sheet, rules))

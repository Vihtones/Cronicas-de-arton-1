extends TestCase
## Combate: o jogador pode atacar um morador (clique fora de combate). O morador vira combatente temporário.


func _morador(w: WorldState) -> String:
	for id in w.modules.npcs.state:
		var s: Dictionary = w.modules.npcs.state[id]
		if s.alive and not s.captive and str(s.location) != "":
			return id
	return ""


func test_morador_morto_ou_preso_nao_pode_ser_alvo() -> void:
	var w := WorldHelpers.world(5)
	var id := _morador(w)
	w.modules.npcs.state[id].alive = false
	var r := WorldHelpers.cmd(w, "StartCombat", {"enemies": [id], "emboscada": false})
	check(not r.accepted, "morto não vira alvo")


func test_morador_perto_vira_alvo_e_entra_na_luta() -> void:
	var w := WorldHelpers.world(5)
	var id := _morador(w)
	var nt: Vector2i = w.modules.npcs.npc_tile(id)
	w.player.position = w.db.tile_to_world(nt)
	var r := WorldHelpers.cmd(w, "StartCombat", {"enemies": [id], "emboscada": false})
	check(r.accepted, "morador ao alcance pode ser atacado: %s" % str(r.errors))
	check(w.modules.combat.active, "a luta começou")
	check(bool(w.modules.combat.creature_state.get(id, {}).get("npc", false)), "o morador entrou como combatente")


func test_morador_longe_nao_pode_ser_atacado() -> void:
	var w := WorldHelpers.world(5)
	var id := _morador(w)
	var nt: Vector2i = w.modules.npcs.npc_tile(id)
	w.player.position = w.db.tile_to_world(nt + Vector2i(20, 0))
	var r := WorldHelpers.cmd(w, "StartCombat", {"enemies": [id], "emboscada": false})
	check(not r.accepted, "a mais de 8 quadrados não há ataque")

extends TestCase

const DIR := "user://test_saves"


func _repo() -> JsonSaveRepository:
	var d := DirAccess.open("user://")
	if d and d.dir_exists("test_saves"):
		for f in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(DIR.path_join(f))
	return JsonSaveRepository.new(DIR)


func test_salvar_e_carregar() -> void:
	var r := _repo()
	eq(r.save("s", {"a": 1, "b": [1, 2]}), OK, "save ok")
	var got := r.load_slot("s")
	eq(int(got.data.a), 1, "dado preservado")
	check(not got.recovered_from_backup, "não usou backup")


func test_corrompido_recupera_do_backup() -> void:
	var r := _repo()
	r.save("s", {"v": 1})
	r.save("s", {"v": 2})  # v1 vira backup
	var f := FileAccess.open(DIR.path_join("s.json"), FileAccess.WRITE)
	f.store_string("{ corrompido")
	f.close()
	var got := r.load_slot("s")
	check(not got.is_empty(), "algo carregou")
	check(got.recovered_from_backup, "veio do backup")
	eq(int(got.data.v), 1, "versão anterior")


func test_checksum_adulterado_rejeitado() -> void:
	var r := _repo()
	r.save("s", {"ouro": 10})
	var path := DIR.path_join("s.json")
	var txt := FileAccess.get_file_as_string(path).replace("10", "9999")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(txt)
	f.close()
	var got := r.load_slot("s")
	check(got.is_empty() or got.recovered_from_backup, "adulteração detectada")


func test_slot_inexistente() -> void:
	eq(_repo().load_slot("nada"), {}, "vazio")

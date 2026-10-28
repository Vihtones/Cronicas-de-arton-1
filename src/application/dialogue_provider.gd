class_name DialogueProvider
extends RefCounted
## Porta de verbalização (§4, §6 Fase 6). Implementação padrão: texto estruturado.
## Provedores de IA só reescrevem o texto; nunca escolhem opções nem resultados.

func provider_id() -> String: return "estruturado"


## Retorna o texto a exibir. `facts` = contexto mínimo permitido (sem segredos).
func verbalize(_npc_id: String, base_text: String, _facts: Dictionary) -> String:
	return base_text


## Versão assíncrona: chama `done.call(text)` (padrão: imediato).
func verbalize_async(npc_id: String, base_text: String, facts: Dictionary, done: Callable) -> void:
	done.call(verbalize(npc_id, base_text, facts))


## Fala livre: o jogador escreveu `ficha.frase` e a regra montou `ficha.base`. O provedor de IA pode devolver uma
## resposta com a voz do morador; o padrão devolve a base. `done.call(texto)` sempre acontece (com fallback).
func converse_async(_npc_id: String, ficha: Dictionary, done: Callable) -> void:
	done.call(str(ficha.get("base", "")))


## true se este provedor gera texto novo (a interface mostra "..." enquanto espera).
func gera_texto() -> bool:
	return false

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

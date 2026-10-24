class_name LocalEchoProvider
extends DialogueProvider
## Provedor "IA" local e determinístico para demonstrar o pipeline da Fase 6 SEM rede:
## reescreve o tom por profissão, nunca muda fatos, opções ou resultados.

const TONES := {"capitã da guarda": "(em tom seco) ", "bêbado": "(arrastando as palavras) ", "clériga de Lena": "(com voz serena) ",
	"ferreiro": "(sem tirar os olhos da bigorna) ", "taverneira": "(enxugando uma caneca) "}

var audit: Array[Dictionary] = []


func provider_id() -> String: return "eco_local"


func verbalize(npc_id: String, base_text: String, facts: Dictionary) -> String:
	var prefix: String = TONES.get(facts.get("profession", ""), "")
	audit.append({"npc": npc_id, "chars": base_text.length(), "changed": prefix != ""})
	return prefix + base_text

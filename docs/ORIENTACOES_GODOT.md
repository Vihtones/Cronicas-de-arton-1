# Orientações do pacote godot-claude-skills aplicadas

Fonte: https://github.com/alexmeckes/godot-claude-skills (MIT). As skills de edição ao vivo
(godot-live-edit, godot-interactive) dependem do editor aberto com o godot-mcp no computador do
usuário e não se aplicam ao ambiente na nuvem; as demais foram usadas como guia.

| Orientação | Onde aplicada |
|---|---|
| Tipos sempre (godot-code-gen) | `tools/check_gdscript_style.py --strict`: funções com retorno tipado, parâmetros e membros tipados, sem sintaxe da Godot 3. 0 apontamentos. |
| Nomes de nó descritivos e grupos (godot-scene-design) | Figurantes, carroças, barracas, telhados, fachadas e pedaços de chão têm nome; grupos `figurantes` e `telhados`. |
| Captura com tempo estável e evidência estruturada (godot-interactive) | Todos os executores de captura esperam `RenderingServer.frame_post_draw` antes de salvar. |
| Desempenho de desenho 2D | Chão decorado assado em texturas por pedaço; telhados e fachadas redesenham só quando mudam; minimapa a 10 quadros/s; cinto de atalhos só redesenha quando o estado muda. |

## Cintilação resolvida
Na Godot 4.3, sob carga de desenho, a tela piscava com blocos pretos (também reproduzido na 0.6.0 com carga
sintética). Medido com capturas da tela real (não do buffer interno):
- Godot 4.7.2 (a versão enviada pelo usuário, conferida pelo SHA-512 oficial) eliminou a cintilação em regime;
- o restante acontecia só enquanto o chão e os telhados eram assados em textura, e agora fica coberto pela tela
  "Preparando a vila..." (uma vez por sessão; depois vem do cache).
Teste final: chuva e festa, 8 capturas cada, sem blocos pretos. Ainda não testado numa placa de vídeo real.

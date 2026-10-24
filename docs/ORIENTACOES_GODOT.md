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

## Achado em aberto
Com renderização por software (llvmpipe, no servidor), a versão 0.7 em andamento mostra blocos
pretos piscando em parte da tela; a 0.6.0 no mesmo teste não mostra. O problema aumenta com a carga
de desenho e some ao retirar a decoração do chão e os telhados. Ainda não confirmado em placa de
vídeo real. Pela diretriz D1, o executável da 0.7 não será gerado até isso ser resolvido.

# IA local de diálogo

O jogo funciona sem IA. Com ela, os moradores reescrevem as respostas na própria voz; os fatos e efeitos continuam decididos pelas regras do jogo.

## Se a IA já vier instalada (pacote com esta pasta completa)

Esta pasta tem `llama-server.exe` e `modelo.gguf`. Basta:

1. Abrir o jogo, apertar Esc (pausa) e clicar em "Ligar IA local".
2. O jogo sobe o servidor sozinho e espera o modelo carregar (pode levar alguns segundos na primeira vez).
3. Para desligar: Esc, "Desligar IA local". Ao fechar o jogo, o servidor é encerrado junto.

## Se a IA não veio no pacote

1. Baixe o **llama.cpp** com build Vulkan (procure "llama.cpp releases" no GitHub; o `llama-server.exe` serve para a RX 580).
2. Baixe um modelo pequeno em GGUF, por exemplo `Qwen2.5-1.5B-Instruct-Q4_K_M.gguf` (procure no Hugging Face).
3. Coloque `llama-server.exe` nesta pasta e renomeie o modelo para `modelo.gguf`.
4. Ou então rode `iniciar.bat C:\caminho\modelo.gguf` numa janela separada: ela serve em `127.0.0.1:8080` e o jogo a encontra ao clicar em "Ligar IA local".

Se aparecer "Servidor de IA local não encontrado", não há servidor nessa porta nem arquivos embutidos.

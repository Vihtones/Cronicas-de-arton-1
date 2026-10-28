#!/bin/bash
# Gera o executável Windows de verdade (template oficial de exportação da Godot 4.7.2) e o verifica
# antes de empacotar. Uso: tools/build_windows.sh <godot_linux> <pasta_saida>
# Verificação: o MESMO conteúdo é exportado como .pck e roda com --autoteste (novo jogo, 2 dias,
# salvar e carregar) fora da pasta do projeto. Se o autoteste falhar, nada é empacotado.
set -euo pipefail
G="$1"; OUT="$2"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VER=$(grep -oP 'CONTENT_VERSION := "\K[^"]+' src/domain/world_state.gd)
mkdir -p build/windows "$OUT"
rm -f build/windows/*
timeout 600 "$G" --headless --path . --export-release "Windows Desktop" build/windows/CronicasDeArton.exe > build/export.log 2>&1
timeout 600 "$G" --headless --path . --export-pack "Windows Desktop" build/verificacao.pck >> build/export.log 2>&1
TMP=$(mktemp -d)
cp build/verificacao.pck "$TMP/"
( cd "$TMP" && timeout 180 "$G" --headless --main-pack verificacao.pck -- --autoteste ) > build/autoteste.log 2>&1 || { echo "AUTOTESTE FALHOU"; cat build/autoteste.log | tail -20; exit 1; }
grep -q "AUTOTESTE .*avancou=true save=true load=true" build/autoteste.log || { echo "AUTOTESTE sem confirmação"; exit 1; }
if grep -q "SCRIPT ERROR" build/autoteste.log; then echo "ERRO DE SCRIPT NO BUILD"; grep "SCRIPT ERROR" build/autoteste.log | head; exit 1; fi
PKG="$TMP/CronicasDeArton"
mkdir -p "$PKG"
cp build/windows/CronicasDeArton.exe "$PKG/"
printf '@echo off\r\nrem Graficos minimos, 30 FPS, sem flashes. Comece por aqui.\r\nstart "" "%%~dp0CronicasDeArton.exe" --rendering-driver opengl3_angle -- --modo-seguro\r\n' > "$PKG/Jogar (modo seguro).bat"
printf '@echo off\r\nrem Modo seguro gravando o registro do jogo em registro.txt (para diagnostico).\r\nstart "" "%%~dp0CronicasDeArton.exe" --verbose --log-file "%%~dp0registro.txt" -- --modo-seguro\r\n' > "$PKG/Diagnostico (gera registro.txt).bat"
cp tools/LEIA-ME-WINDOWS.txt "$PKG/LEIA-ME.txt"
mkdir -p "$PKG/IA local"
cp tools/ia_local/LEIA-ME.md "$PKG/IA local/LEIA-ME.md"
cp tools/ia_local/iniciar.bat "$PKG/IA local/iniciar.bat"
# IA embutida (opcional): IA_SERVIDOR = llama-server.exe (build Vulkan do llama.cpp, com as DLLs ao lado),
# IA_MODELO = modelo .gguf. Sem o modelo, o servidor vai junto e o modelo entra como arquivo modelo.gguf na pasta.
if [ -n "${IA_SERVIDOR:-}" ]; then
  cp "$IA_SERVIDOR" "$PKG/IA local/llama-server.exe"
  cp "$(dirname "$IA_SERVIDOR")"/*.dll "$PKG/IA local/" 2>/dev/null || true
  echo "IA embutida: servidor incluído"
fi
if [ -n "${IA_MODELO:-}" ]; then
  cp "$IA_MODELO" "$PKG/IA local/modelo.gguf"
  echo "IA embutida: modelo incluído"
else
  echo "AVISO: modelo.gguf NÃO incluído (copie-o para a pasta IA local do pacote)"
fi
( cd "$PKG" && sha256sum CronicasDeArton.exe > SHA256.txt )
( cd "$TMP" && zip -qr "$OUT/CronicasDeArton-v$VER-Windows.zip" CronicasDeArton )
echo "OK versão $VER"
grep AUTOTESTE build/autoteste.log
sha256sum build/windows/CronicasDeArton.exe
ls -la "$OUT/CronicasDeArton-v$VER-Windows.zip"
rm -rf "$TMP"

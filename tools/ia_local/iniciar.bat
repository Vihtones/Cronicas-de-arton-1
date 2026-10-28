@echo off
llama-server.exe -m %1 --host 127.0.0.1 --port 8080 -ngl 99 -c 2048

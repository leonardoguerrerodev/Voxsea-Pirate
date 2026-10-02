#!/usr/bin/env bash
# Borra la partida guardada (user://partida.json) para que el próximo Play empiece limpio.
# Cerrar el juego antes: al salir guarda de nuevo (SaveGame.save_and_quit).
# Solo toca la partida: logs y caché de shaders se quedan.
set -euo pipefail
save="${XDG_DATA_HOME:-$HOME/.local/share}/godot/app_userdata/Voxsea Pirate/partida.json"
if [[ -f "$save" ]]; then
	rm -- "$save"
	echo "Partida borrada: $save"
else
	echo "No hay partida guardada ($save)"
fi

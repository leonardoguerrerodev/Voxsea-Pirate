# Pendientes

Lista viva de lo que falta (2026-10-01, después del commit `0df408c`). Se marca al terminar; el detalle de cada fase está en `docs/plan.md` y el estado general en `CLAUDE.md`.

Orden sugerido: **guardado → escotilla y bodega → combate** (el combate necesita los cañones por piezas: pasar esa hoja por Tripo pronto).

## Ahora (deuda del barco actual)

- [ ] Medir FPS en el Nobara a 1440p con cada interruptor de menú dev → Gráficos (Leo)
- [x] Guardar y cargar partida (`user://partida.json`: inventario, objetos colocados, barco, jugador, hora; al salir y desde la pausa)
- [x] Bodega: rejilla que deja ver y pasar la luz, E para bajar/subir (`HatchControl`), escala de palos y piso (`HoldInterior`, con farol)
- [x] Mástil modelado (mástil + verga + cofa) con vela cuadra colgada de la verga
- [ ] Colgar objetos en paredes (campana, repisa, soporte): hoy solo se apoyan en pisos
- [ ] Estela del barco al avanzar (espuma detrás y a los costados)
- [ ] Pruebas a mano: sensación de navegación (`ShipRig.sail_scale`), brillo de la noche
- [ ] Repo de GitHub público: `CLAUDE.md` dice privado; decidir
- [ ] Licencia de Tripo (plan gratis, no comercial): antes de vender, plan pago o rehacer los modelos

## Arte pendiente (Tripo, exportar "por piezas"; hojas de ≤ 13 objetos)

- [ ] Cañones por piezas (tubo aparte de la cureña): necesario para apuntar y disparar
- [x] Timón (rueda + pedestal), farol, cabrestante y caja de balas (2026-10-01)
- [ ] Hoja de cubierta: ancla, barril + tapa
- [ ] Cabrestante funcional (levar el ancla); farol colgable de un gancho
- [ ] Escala de palos con modelo (hoy primitivas) y subirla trepando en vez de teletransporte
- [ ] Probar a mano el empuje de la vela (`side_push`, `sail_scale`) en el barco de 16 m
- [ ] Hoja de pesca: caña, carrete, anzuelo, arpón, cuerda, flotador, caja de anzuelos, peces
- [ ] Hoja de mástiles (prompt para ChatGPT listo)
- [ ] Props de varios materiales: cofre con herrajes, botella de vidrio transparente
- [ ] Tela de la hamaca (plano curvo con lona, como la vela)
- [ ] Segundo casco más grande (bergantín o galeón): más bodega y más cañones
- [ ] Personajes y criaturas: Bartolo, tiburón, Abisales

## Combate (fase 6, estilo Sea of Thieves)

- [x] Cañón funcional: E lo toma (cámara propia), el mouse apunta (giro ±45°, tubo −10° a +30°), clic dispara una bala del inventario, recarga 3 s
- [ ] Cañón: animación de cargar con el atacador, sonido, humo con textura
- [x] Proyectil balístico con detección de impacto por rayo (salpica en el mar; falta daño)
- [ ] Agujeros en el punto de impacto, con fuga
- [ ] Nivel de agua por barco: si sube, el barco se hunde
- [ ] Balde para achicar y tablones para tapar agujeros
- [ ] Restos flotantes recolectables

## Pesca (fase 8)

- [ ] Caña con minijuego de tensión
- [ ] Peces según zona y hora
- [ ] Carnada que atrae peces o Abisales
- [ ] Red de arrastre (pieza del barco, lo frena) y arpón

## Cocina

- [ ] Estufa funcional: fuego encendido, humo
- [ ] Recetas: pescado crudo → asado (y quemado si se pasa)
- [ ] Comer: ¿hambre o bonus? (decisión de diseño pendiente)

## Inventario

- [ ] Fuentes de objetos: pesca, cocina, botín, restos flotantes (hoy solo el botón dev)
- [ ] Objeto en la mano o barra rápida (caña, balde, tablón)
- [ ] Soltar o tirar objetos al mar; bodega del barco como almacenamiento con capacidad

## Mundo y progresión

- [ ] Fase 7: primer Abisal (tiburón con IA, embestida, vida, botín)
- [ ] Rebanada vertical: isla + astillero + aguas someras, ~20 min de principio a fin
- [ ] Fase 9: Bartolo (tienda de cascos y planos), economía en pescado
- [ ] Fase 10: zonas (mar abierto, fosas, el Ojo) y Saqueadores (la máscara de agua hoy soporta un solo barco)
- [ ] Fase 11: cooperativo online

## Mar (opcional)

- [ ] Capa FFT solo visual sobre las olas Gerstner (la física sigue en Gerstner, regla 1)
- [ ] Salpicaduras en la proa y espuma alrededor del casco en movimiento

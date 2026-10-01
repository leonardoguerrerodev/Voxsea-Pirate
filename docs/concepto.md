# Concepto

## Pitch

Voxsea Pirate es un juego 3D de supervivencia naval con humor. Construyes tu barco con voxels, lo sacas a un mar con olas reales y vuelves con materiales para hacerlo más grande, más fuerte o más rápido. Si lo construyes mal, se da vuelta en el puerto.

## Ciclo de juego

1. Zarpas desde el astillero de Bartolo.
2. Exploras, pescas y combates.
3. Recolectas materiales: madera de naufragios, hierro de ruinas, escamas y huesos de Abisales.
4. Vuelves y amplías o rediseñas el barco.
5. Con un barco mejor, llegas a aguas más peligrosas.

## Reglas de diseño

**El barco es el personaje.** El pirata no tiene niveles ni stats. Toda la progresión vive en el barco: tamaño, materiales, piezas.

**La construcción tiene consecuencias físicas.** La masa y la forma deciden cómo flota el barco. Un barco con mucho peso arriba escora; uno sin casco cerrado se hunde.

**El daño es real.** Los cañonazos y las mordidas arrancan voxels. Un agujero bajo la línea de flotación inunda ese compartimento.

**Las actividades se alimentan entre sí.** La pesca da carnada y moneda; la carnada atrae Abisales; los Abisales dan materiales; los materiales mejoran el barco.

**El fracaso es gracioso, no frustrante.** Hundirse cuesta parte del cargamento, no el barco. Bartolo siempre tiene un comentario.

## Sistemas

### Construcción

Voxels de 0,5 m con material. Se colocan en una grilla local al barco, de hasta 64 × 32 × 128 voxels. El modo construcción solo funciona en el astillero o anclado en una costa. Estilo visual: bloques con bordes suavizados, en la línea de Enshrouded.

Además de voxels, el barco acepta **piezas funcionales** que ocupan celdas de la grilla: mástil, vela, timón, cañón, red de arrastre, ancla, farol, bodega.

| Material | Densidad | Resistencia | Origen |
|---|---|---|---|
| Madera de deriva | Baja | Baja | Playas, restos flotantes |
| Tablón | Media | Media | Ruinas, comercio con Bartolo |
| Hierro | Alta | Alta | Ruinas hundidas |
| Lona | Muy baja | Muy baja | Solo para velas |
| Hueso de Abisal | Baja | Alta | Abisales grandes |
| Escama de Abisal | Media | Muy alta | Abisales grandes, blindaje |

### Flotabilidad e inundación

El barco flota por volumen desplazado: casco más aire interior estanco. El juego detecta compartimentos cerrados con flood fill. Si un compartimento tiene una brecha bajo el agua, se llena de a poco. Se puede reparar en el mar con tablones, pero tapar un agujero bajo la línea de flotación es más lento.

### Navegación

Velas y viento. La velocidad depende de la superficie de vela, el ángulo respecto del viento, la masa y la forma del casco. El timón gira el barco; un barco largo gira más lento. El ancla lo detiene.

### Combate

Cañones como piezas del barco, con arco de tiro limitado según dónde los pongas. Se apunta por banda (babor o estribor). Los proyectiles siguen un arco balístico y arrancan voxels en el punto de impacto. Munición: balas de hierro, metralla, arpones con cadena.

### Pesca

Tres herramientas:

- **Caña:** desde cubierta, minijuego de tensión. Peces comunes y raros.
- **Red de arrastre:** pieza del barco. Pesca sola mientras navegas, pero frena el barco.
- **Arpón:** para presas grandes. Engancha al pez o al Abisal y arrastra el barco.

El pescado sirve como moneda con Bartolo y como carnada. Cada zona tiene su tabla de peces.

### Progresión

No hay árbol de habilidades. Avanzas porque desbloqueas materiales y piezas, y porque un barco mejor sobrevive en zonas más profundas. Bartolo vende planos de piezas a cambio de pescado.

### Cooperativo (futuro)

Hasta cuatro jugadores en un barco. Uno al timón, otros en cañones, velas o reparaciones. La arquitectura se prepara desde el inicio: ediciones como comandos y simulación separada de la presentación.

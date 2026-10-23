# Cambiar de clase un tipo de caso (hecho)

> **Estado: ✅ HECHO** (2026-10-22). Relacionado: [[Plan-Clase-Comercial]] · [[Plan-Columnas-Por-Tipo]] · [[Trampas]]

## Regla

La clase vive en el **tipo** y sus casos la heredan (no hay clase por caso). Por eso un tipo
**con casos no cambia de clase en su lugar**: sus casos cambiarían con él. El usuario pidió:
«lo que ya está se queda igual; solo los nuevos nacen en la clase nueva».

## Cómo funciona — `Cases::TypeClassChange` (`POST case_types/:id/change_class`, solo admin)

- **Sin casos:** cambia directo; `CaseType#reseed_columns_for_new_class` pone las etapas de la
  clase nueva.
- **Con casos:**
  1. crea un tipo NUEVO en la otra clase con el mismo nombre, color, posición, prefijo, ITIL,
     campos personalizados, servicios y categorías (con subcategorías); sus etapas son las de la
     clase nueva (las tareas de etapa no se copian: son de otra clase);
  2. copia los contadores de folio `type:<viejo>[:periodo]` → `type:<nuevo>` (la serie sigue,
     sin repetir folios con el mismo prefijo);
  3. el tipo de antes queda **retirado** (`case_types.retired_at`, migración
     `20261027150000_add_retired_at_to_case_types`) y se llama «… (anterior)»; sus casos no se
     tocan (clase, etapas, datos, historia, métricas);
  4. automatizaciones `assign_case_type` con el id viejo → id nuevo; reglas de casos con condición
     `case_type` que lo nombran suman el nuevo (`eq`→`in`, `neq`→`not_in`).
- **Tipo retirado:** `CaseTicket#case_type_not_retired` impide crear un caso o cambiarle el tipo a
  uno retirado (cubre todos los caminos); el tipo por defecto, `@crear_ticket(tipo=)`, la IA de
  alta, «Asignar Caso» y el portal usan solo `CaseType.active`. En el front, `creatableTypes`
  (helper/caseClasses.js) lo quita de los selectores de alta y de cambio de tipo; Lista, Tablero y
  filtros sí lo muestran para seguir trabajando sus casos.
- UI: Tipos de caso → botón ⇄ «Cambiar de clase» (`typeDetail/ChangeClassModal.vue`, explica qué
  pasa según tenga casos o no) y etiqueta «Retirado».
- Pruebas: `type_class_change_spec.rb` (6) y `case_types_change_class_spec.rb` (3).

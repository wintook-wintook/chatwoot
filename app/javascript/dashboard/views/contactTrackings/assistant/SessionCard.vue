<script>
// proyecto@asistente_agentes_ia — DE QUÉ CONVERSACIÓN SE TRATA
// ============================================================================
// Un card de DOS LÍNEAS encima de la conversación. Es referencia y nada más: no
// se toca, no navega, no cambia de estado.
//
// POR QUÉ EXISTE:
//   La pantalla mostraba el hilo y el borrador sin decir en CUÁL de las
//   conversaciones estabas. Con doce en el listado eso no es un detalle: se
//   retoma una, se la confunde con otra, y se guarda encima del Agente IA
//   equivocado.
//
// POR QUÉ DOS LÍNEAS Y TRUNCADAS:
//   Vive sobre la conversación, que es la mitad útil de la pantalla. Un card que
//   crece con el largo del título le come alto al hilo, y el título sale del
//   primer mensaje de la persona: puede tener 80 caracteres. Dos líneas fijas y
//   lo que no entra se corta — para leerlo completo está el hilo, justo abajo.
//
//   `truncate` necesita que el contenedor pueda encogerse: de ahí el min-w-0 en
//   la línea del título. Sin eso el texto empuja el ancho y no se corta nunca.
//
// El id es lo único con lo que dos conversaciones del mismo día sobre el mismo
// agente se distinguen: esta tabla no tiene folio ni serie.
// ============================================================================
export default {
  props: {
    // id, status, title, template_name, created_at, updated_at. Null mientras no
    // se guardó ningún turno.
    sessionMeta: { type: Object, default: null },
    // El Agente IA del que salió el borrador cuando se entró desde su ficha,
    // antes de que haya conversación guardada.
    editingTemplate: { type: Object, default: null },
  },
  computed: {
    fromTemplate() {
      return (
        this.editingTemplate?.name || this.sessionMeta?.template_name || ''
      );
    },
    created() {
      return this.formatted(this.sessionMeta?.created_at);
    },
    updated() {
      return this.formatted(this.sessionMeta?.updated_at);
    },
  },
  methods: {
    // Día y mes con dos dígitos y el año completo: "9/9, 15:36" obliga a deducir
    // el año, y en un listado donde conviven conversaciones de hace una semana y
    // de hace dos meses eso se lee mal. Queda "09/09/2026 15:36".
    //
    // El orden de los campos y el reloj los decide el navegador, no un formato
    // clavado: el Asistente habla los dos idiomas, así que un dd/mm/aaaa fijo le
    // mostraría las fechas al revés a una cuenta en inglés. Lo único que se le
    // quita es la coma que toLocaleString mete entre la fecha y la hora.
    formatted(value) {
      if (!value) return '';

      return new Date(value)
        .toLocaleString(undefined, {
          day: '2-digit',
          month: '2-digit',
          year: 'numeric',
          hour: '2-digit',
          minute: '2-digit',
          // 24 horas siempre. Sin fijarlo, el mismo dato sale "15:36" en Chrome
          // y "09:36 p.m." en otro motor con el mismo locale, y "09:36" a secas
          // se confunde con la mañana.
          hour12: false,
        })
        .replace(',', '');
    },
  },
};
</script>

<template>
  <div
    class="px-3 py-2 border rounded-lg shrink-0 bg-slate-25 dark:bg-slate-900/40 border-slate-100 dark:border-slate-700"
  >
    <!-- LÍNEA 1 · quién es: el id y de qué se trataba -->
    <div class="flex items-baseline gap-2 flex-nowrap">
      <span
        v-if="sessionMeta"
        class="font-mono text-xs text-slate-400 dark:text-slate-500 shrink-0 whitespace-nowrap"
      >
        #{{ sessionMeta.id }}
      </span>
      <span
        v-if="sessionMeta && sessionMeta.title"
        class="min-w-0 text-xs truncate text-slate-700 dark:text-slate-200"
      >
        {{ sessionMeta.title }}
      </span>
      <span v-else class="text-xs italic text-slate-400 dark:text-slate-500">
        {{ $t('TRACKING_ASSISTANT_VIEW.SESSION_UNSAVED') }}
      </span>
    </div>

    <!-- LÍNEA 2 · de dónde salió y cuándo -->
    <div
      class="text-xs truncate text-slate-400 dark:text-slate-500"
      :class="{ 'mt-0.5': sessionMeta }"
    >
      <!-- Las fechas van PRIMERO y con rótulo. Antes decía "· creada 9/9, 15:36
           · guardada 10/9, 15:36": dos bullets, sin año, y con "guardada" que se
           confunde con el guardado del Agente IA. Y van antes que el nombre del
           agente para que, si la línea se corta, lo que se pierda sea el nombre
           largo y no la fecha. -->
      <span v-if="created" class="whitespace-nowrap">
        {{ $t('TRACKING_ASSISTANT_VIEW.SESSION_CREATED_AT') }}
        <span class="text-slate-500 dark:text-slate-400">{{ created }}</span>
      </span>
      <span v-if="updated" class="ml-2 whitespace-nowrap">
        {{ $t('TRACKING_ASSISTANT_VIEW.SESSION_SAVED_AT') }}
        <span class="text-slate-500 dark:text-slate-400">{{ updated }}</span>
      </span>
      <span v-if="fromTemplate" class="ml-2">
        {{ $t('TRACKING_ASSISTANT_VIEW.SESSION_FROM', { name: fromTemplate }) }}
      </span>
    </div>
  </div>
</template>

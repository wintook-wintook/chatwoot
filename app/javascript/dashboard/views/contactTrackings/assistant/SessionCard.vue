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
    // id, status, title, named, template_name, created_at, updated_at. Null mientras
    // no se guardó ningún turno.
    sessionMeta: { type: Object, default: null },
    // El Agente IA del que salió el borrador cuando se entró desde su ficha,
    // antes de que haya conversación guardada.
    editingTemplate: { type: Object, default: null },
  },
  // rename: nombre puesto a mano (25/09/2026), el lápiz junto al título. Vacío
  // vuelve al título automático.
  emits: ['rename'],
  data() {
    return { editing: false, draftName: '' };
  },
  computed: {
    // Con nombre puesto a mano, ese manda; si no, el agente o de qué trata.
    heading() {
      if (this.sessionMeta?.named) return this.sessionMeta.title;
      return (
        this.fromTemplate ||
        this.sessionMeta?.title ||
        this.$t('TRACKING_ASSISTANT_VIEW.SESSION_UNSAVED')
      );
    },
    // Solo si es de otra persona: en la propia, el nombre no aporta nada.
    creator() {
      return this.sessionMeta && !this.sessionMeta.mine
        ? this.sessionMeta.creator
        : '';
    },
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
    startRename() {
      this.draftName = this.sessionMeta?.named ? this.sessionMeta.title : '';
      this.editing = true;
      this.$nextTick(() => this.$refs.nameInput?.focus());
    },
    submitRename() {
      if (!this.editing) return;
      this.editing = false;
      this.$emit('rename', this.draftName.trim());
    },
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
  <!-- Qué se está editando (pedido del usuario, 24/09/2026: la franja de arriba se veía
       desordenada). Título en grande —el agente, o de qué trata la conversación— y
       debajo, en gris y en una línea, el número, las fechas y quién la creó. El marco
       lo pone la barra de Assistant.vue, que junta esto con el canal y las acciones. -->
  <div class="min-w-0">
    <div v-if="editing" class="flex items-center gap-1">
      <input
        ref="nameInput"
        v-model="draftName"
        type="text"
        maxlength="120"
        class="!mb-0 !py-1 text-sm"
        :placeholder="$t('TRACKING_ASSISTANT_VIEW.SESSION_RENAME_PLACEHOLDER')"
        @keydown.enter.prevent="submitRename"
        @keydown.esc.prevent="editing = false"
      />
      <woot-button size="tiny" icon="checkmark" @click="submitRename" />
      <woot-button
        size="tiny"
        variant="clear"
        color-scheme="secondary"
        icon="dismiss"
        @click="editing = false"
      />
    </div>
    <div v-else class="flex items-center min-w-0 gap-1">
      <p
        class="!m-0 text-sm font-medium truncate text-slate-800 dark:text-slate-100"
      >
        {{ heading }}
      </p>
      <woot-button
        v-if="sessionMeta"
        v-tooltip="$t('TRACKING_ASSISTANT_VIEW.SESSION_RENAME')"
        size="tiny"
        variant="clear"
        color-scheme="secondary"
        icon="edit"
        class="shrink-0"
        @click="startRename"
      />
    </div>
    <p
      v-if="sessionMeta"
      class="!m-0 mt-0.5 text-xs truncate text-slate-500 dark:text-slate-400"
    >
      <span class="font-mono">#{{ sessionMeta.id }}</span>
      <template v-if="sessionMeta.named && fromTemplate">
        · {{ fromTemplate }}
      </template>
      <template v-else-if="fromTemplate && sessionMeta.title">
        · {{ sessionMeta.title }}
      </template>
      <template v-if="created">
        · {{ $t('TRACKING_ASSISTANT_VIEW.SESSION_CREATED_AT') }} {{ created }}
      </template>
      <template v-if="updated">
        · {{ $t('TRACKING_ASSISTANT_VIEW.SESSION_SAVED_AT') }} {{ updated }}
      </template>
      <template v-if="creator">
        · {{ $t('TRACKING_ASSISTANT_VIEW.SESSION_CREATOR', { name: creator }) }}
      </template>
    </p>
  </div>
</template>

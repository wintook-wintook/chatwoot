<script>
// proyecto@asistente_agentes_ia — QUÉ ESTOY ARMANDO Y EN QUÉ VA
// ============================================================================
// Dos líneas arriba del Entrenamiento: la IDENTIDAD de la conversación y los
// cuatro HITOS del trabajo.
//
// LA IDENTIDAD, porque la pantalla mostraba el hilo y el borrador sin decir en
// cuál de las conversaciones estabas. Con doce en el listado eso es un problema
// real: se retoma una, se la confunde con otra, y se guarda encima del Agente IA
// equivocado. El id es lo único con lo que dos conversaciones del mismo día
// sobre el mismo agente se distinguen.
//
// LOS HITOS, porque ninguno de los tres paneles decía en qué estado estaba lo
// que estabas armando. Se podía llegar a guardar un agente sin haberlo probado
// nunca, y nada lo señalaba.
//
// NO GUARDA NADA. Los cuatro estados se derivan de lo que ya hay en la vista
// —la conversación, el borrador, la última comprobación, la última prueba—, así
// que no puede desincronizarse de la realidad: si el borrador cambia, la
// comprobación cambia con él y el hito lo refleja solo.
//
// "Comprobado" es el único que puede quedar en ROJO en vez de en gris: los
// demás son "hecho o todavía no", pero una comprobación con hallazgos
// bloqueantes es una parada, no una etapa pendiente.
//
// "Probado" se apaga cuando el borrador cambia después de la prueba: un
// resultado de hace tres ediciones no dice nada del texto que hay ahora, y
// dejarlo en verde sería peor que no mostrarlo.
// ============================================================================
export default {
  props: {
    messages: { type: Array, default: () => [] },
    draft: { type: String, default: '' },
    validation: { type: Object, default: null },
    dryRun: { type: Object, default: null },
    // El Agente IA del que salió el borrador, si salió de uno.
    editingTemplate: { type: Object, default: null },
    // Identidad de la conversación guardada: id, estado y fechas. Llega null
    // mientras no se guardó ningún turno todavía.
    sessionMeta: { type: Object, default: null },
  },
  computed: {
    // De qué Agente IA salió el borrador. Puede venir por dos caminos —se entró
    // desde la ficha del agente, o la conversación guardada lo recuerda— y los
    // dos tienen que mostrar lo mismo.
    fromTemplate() {
      return (
        this.editingTemplate?.name || this.sessionMeta?.template_name || ''
      );
    },
    hasDraft() {
      return this.draft.trim().length > 0;
    },
    blockingCount() {
      return this.validation?.blocking?.length || 0;
    },
    routeCount() {
      return this.validation?.routes?.length || 0;
    },
    // Qué se muestra al lado de "Comprobado": los problemas si los hay, y si no,
    // cuántos temas leyó el motor. Nunca las dos cosas — la tira es una línea.
    checkedDetail() {
      if (this.blockingCount > 0) {
        return this.$t('TRACKING_ASSISTANT_VIEW.STEP_CHECKED_BLOCKED', {
          count: this.blockingCount,
        });
      }
      if (!this.routeCount) return null;

      return this.$t('TRACKING_ASSISTANT_VIEW.STEP_CHECKED_ROUTES', {
        count: this.routeCount,
      });
    },
    steps() {
      return [
        {
          key: 'interview',
          label: this.$t('TRACKING_ASSISTANT_VIEW.STEP_INTERVIEW'),
          done: this.messages.length > 0 || Boolean(this.editingTemplate),
          detail: null,
        },
        {
          key: 'draft',
          label: this.$t('TRACKING_ASSISTANT_VIEW.STEP_DRAFT'),
          done: this.hasDraft,
          detail: null,
        },
        {
          key: 'checked',
          label: this.$t('TRACKING_ASSISTANT_VIEW.STEP_CHECKED'),
          // Comprobado y limpio. Con bloqueantes NO está hecho: está frenado.
          done: Boolean(this.validation) && this.blockingCount === 0,
          alert: this.blockingCount > 0,
          detail: this.checkedDetail,
        },
        {
          key: 'tested',
          label: this.$t('TRACKING_ASSISTANT_VIEW.STEP_TESTED'),
          done: Boolean(this.dryRun),
          detail: this.dryRun?.routes?.chosen || null,
        },
      ];
    },
    // El idioma sale del navegador y no de un 'es-MX' fijo: el Asistente habla
    // los dos idiomas.
    formatted() {
      const meta = this.sessionMeta;
      if (!meta) return null;

      const fmt = value =>
        value
          ? new Date(value).toLocaleString(undefined, {
              day: '2-digit',
              month: '2-digit',
              hour: '2-digit',
              minute: '2-digit',
            })
          : null;

      return { created: fmt(meta.created_at), updated: fmt(meta.updated_at) };
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-1">
    <!-- IDENTIDAD -->
    <div
      class="flex flex-wrap items-center text-xs gap-x-2 text-slate-500 dark:text-slate-400"
    >
      <span
        v-if="sessionMeta"
        class="font-mono text-slate-400 dark:text-slate-500"
      >
        #{{ sessionMeta.id }}
      </span>
      <span v-else class="italic">
        {{ $t('TRACKING_ASSISTANT_VIEW.SESSION_UNSAVED') }}
      </span>

      <span v-if="fromTemplate" class="truncate">
        {{ $t('TRACKING_ASSISTANT_VIEW.SESSION_FROM', { name: fromTemplate }) }}
      </span>

      <span v-if="formatted && formatted.created" class="whitespace-nowrap">
        {{
          $t('TRACKING_ASSISTANT_VIEW.SESSION_CREATED_AT', {
            date: formatted.created,
          })
        }}
      </span>
      <span v-if="formatted && formatted.updated" class="whitespace-nowrap">
        {{
          $t('TRACKING_ASSISTANT_VIEW.SESSION_SAVED_AT', {
            date: formatted.updated,
          })
        }}
      </span>
    </div>

    <!-- HITOS -->
    <div class="flex items-center flex-wrap gap-x-1 gap-y-1 text-xs">
      <span
        v-for="(step, index) in steps"
        :key="step.key"
        class="flex items-center gap-1"
        :class="{
          'text-red-600 dark:text-red-400': step.alert,
          'text-slate-700 dark:text-slate-200': step.done && !step.alert,
          'text-slate-400 dark:text-slate-500': !step.done && !step.alert,
        }"
      >
        <fluent-icon
          v-if="index > 0"
          icon="chevron-right"
          size="12"
          class="shrink-0 text-slate-300 dark:text-slate-600"
        />
        <fluent-icon
          v-if="step.alert"
          icon="warning"
          size="12"
          class="shrink-0"
        />
        <fluent-icon
          v-else-if="step.done"
          icon="checkmark"
          size="12"
          class="shrink-0"
        />
        <span
          v-else
          class="w-1.5 h-1.5 rounded-full bg-slate-300 dark:bg-slate-600 shrink-0"
        />
        {{ step.label }}
        <span
          v-if="step.detail"
          class="text-slate-400 dark:text-slate-500 font-normal"
        >
          {{ step.detail }}
        </span>
      </span>
    </div>
  </div>
</template>

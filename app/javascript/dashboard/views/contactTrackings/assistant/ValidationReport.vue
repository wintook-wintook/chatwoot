<script>
// proyecto@asistente_agentes_ia — F4
// ============================================================================
// "Lo que el motor va a leer". NO dice "parece correcto": muestra las ramas que
// el parser de producción efectivamente reconoció y en qué fuente va a buscar
// cada una. Si dice 0 ramas, el agente no ejecuta nada — y se ve acá, antes de
// guardar, en vez de en producción tres semanas después.
//
// TAMBIÉN ES EL ÍNDICE. Cada rama y cada hallazgo con línea llevan al lugar
// exacto del Entrenamiento. En un texto de 645 líneas —los hay en esta cuenta—
// saber que "la rama comercial no tiene descripción" no sirve si después hay que
// buscarla a mano; el comprobador ya sabe dónde está.
//
// Los hallazgos se muestran con las cuatro partes que trae el comprobador:
// dónde, qué pasa, por qué, y qué se escribió. Recortarlos "para que se vean
// más limpios" es justo lo que los vuelve inútiles.
//
// Esto es SOLO EL DETALLE. El marco, el título y el resumen los pone el
// acordeón que lo contiene (Assistant.vue + ValidationBadge): el detalle ocupaba
// diez líneas permanentes en la misma columna donde se edita un Entrenamiento
// que acá tiene 46 líneas de mediana, así que se colapsa y lo que queda siempre
// a la vista es el resumen.
// ============================================================================
export default {
  props: {
    validation: { type: Object, default: null },
  },
  emits: ['gotoRoute', 'gotoLine'],
  computed: {
    routes() {
      return this.validation?.routes || [];
    },
    blocking() {
      return this.validation?.blocking || [];
    },
    degrading() {
      return this.validation?.degrading || [];
    },
    cosmetic() {
      return this.validation?.cosmetic || [];
    },
  },
};
</script>

<template>
  <div>
    <p v-if="!validation" class="text-xs text-slate-500 dark:text-slate-400">
      {{ $t('TRACKING_ASSISTANT_VIEW.REPORT_EMPTY') }}
    </p>

    <!-- Las ramas, con la fuente ya resuelta: esto es lo que va a pasar. -->
    <ul v-if="routes.length" class="flex flex-col gap-2 mb-3">
      <li
        v-for="route in routes"
        :key="route.name"
        class="text-xs border-l-2 border-slate-200 dark:border-slate-600 pl-2"
      >
        <div class="flex items-center gap-2">
          <button
            class="p-0 font-medium underline rounded-none cursor-pointer text-slate-800 dark:text-slate-100 decoration-dotted underline-offset-2 hover:text-woot-600 dark:hover:text-woot-400"
            :title="$t('TRACKING_ASSISTANT_VIEW.REPORT_GOTO')"
            @click="$emit('gotoRoute', route.name)"
          >
            {{ route.name }}
          </button>
          <span v-if="route.tag" class="text-slate-500 dark:text-slate-400">{{
            route.tag
          }}</span>
        </div>
        <div class="text-slate-500 dark:text-slate-400">
          {{ $t('TRACKING_ASSISTANT_VIEW.REPORT_SOURCE') }}:
          <code>{{
            route.directive || $t('TRACKING_ASSISTANT_VIEW.REPORT_NO_SOURCE')
          }}</code>
        </div>
        <div v-if="route.escalation" class="text-slate-500 dark:text-slate-400">
          {{ $t('TRACKING_ASSISTANT_VIEW.REPORT_ESCALATION') }}:
          <code>{{ route.escalation }}</code>
        </div>
      </li>
    </ul>

    <p
      v-if="validation && validation.default_route"
      class="text-xs text-slate-500 dark:text-slate-400 mb-3"
    >
      {{ $t('TRACKING_ASSISTANT_VIEW.REPORT_DEFAULT') }}:
      {{ validation.default_route }}
    </p>

    <!-- Hallazgos. El texto va completo: es lo que permite corregir. -->
    <div
      v-for="group in [
        { items: blocking, tone: 'red', icon: '✗' },
        { items: degrading, tone: 'amber', icon: '⚠' },
        { items: cosmetic, tone: 'slate', icon: '·' },
      ]"
      :key="group.tone"
    >
      <div
        v-for="finding in group.items"
        :key="finding.code + (finding.line || '')"
        class="text-xs mb-2"
        :class="{
          'text-red-700 dark:text-red-300': group.tone === 'red',
          'text-amber-700 dark:text-amber-400': group.tone === 'amber',
          'text-slate-500 dark:text-slate-400': group.tone === 'slate',
        }"
      >
        <span class="font-medium">{{ group.icon }}</span>
        <!-- El comprobador ya sabe en qué línea está; el hallazgo lleva hasta
             ahí en vez de dejar a alguien buscándola. -->
        <button
          v-if="finding.line"
          class="p-0 font-medium underline rounded-none cursor-pointer decoration-dotted underline-offset-2"
          :title="$t('TRACKING_ASSISTANT_VIEW.REPORT_GOTO')"
          @click="$emit('gotoLine', finding.line)"
        >
          {{ finding.message }}
        </button>
        <template v-else>{{ finding.message }}</template>
        <div
          v-if="finding.wrote"
          class="mt-1 px-2 py-1 rounded bg-slate-50 dark:bg-slate-900 font-mono text-slate-600 dark:text-slate-300 overflow-x-auto"
        >
          {{ finding.wrote }}
        </div>
      </div>
    </div>
  </div>
</template>

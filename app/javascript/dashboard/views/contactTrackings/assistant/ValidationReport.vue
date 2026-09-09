<script>
// proyecto@asistente_agentes_ia — F4
// ============================================================================
// "Lo que el motor va a leer". NO dice "parece correcto": muestra las ramas que
// el parser de producción efectivamente reconoció y en qué fuente va a buscar
// cada una. Si dice 0 ramas, el agente no ejecuta nada — y se ve acá, antes de
// guardar, en vez de en producción tres semanas después.
//
// Los hallazgos se muestran con las cuatro partes que trae el comprobador:
// dónde, qué pasa, por qué, y qué se escribió. Recortarlos "para que se vean
// más limpios" es justo lo que los vuelve inútiles.
// ============================================================================
export default {
  props: {
    validation: { type: Object, default: null },
    isChecking: { type: Boolean, default: false },
  },
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
    // Sin ramas el agente cae siempre al camino conversacional: es el estado que
    // hay que gritar, no un detalle más de la lista.
    hasNoRoutes() {
      return this.validation && this.routes.length === 0;
    },
  },
};
</script>

<template>
  <div
    class="p-4 bg-white rounded-lg dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
  >
    <div class="flex items-center justify-between mb-3">
      <h3 class="text-sm font-semibold text-slate-800 dark:text-slate-100">
        {{ $t('TRACKING_ASSISTANT_VIEW.REPORT_TITLE') }}
      </h3>
      <span
        v-if="isChecking"
        class="text-xs text-slate-400 dark:text-slate-500"
      >
        {{ $t('TRACKING_ASSISTANT_VIEW.REPORT_CHECKING') }}
      </span>
      <span
        v-else-if="validation"
        class="text-xs font-medium px-2 py-0.5 rounded"
        :class="
          hasNoRoutes || blocking.length
            ? 'text-red-700 bg-red-100 dark:bg-red-900/30 dark:text-red-300'
            : 'text-green-700 bg-green-100 dark:bg-green-900/30 dark:text-green-300'
        "
      >
        {{
          hasNoRoutes
            ? $t('TRACKING_ASSISTANT_VIEW.REPORT_NO_ROUTES')
            : $t('TRACKING_ASSISTANT_VIEW.REPORT_ROUTES', {
                count: routes.length,
              })
        }}
      </span>
    </div>

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
          <span class="font-medium text-slate-800 dark:text-slate-100">{{
            route.name
          }}</span>
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
        {{ finding.message }}
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

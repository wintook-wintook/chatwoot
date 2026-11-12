<script>
// feat/ficha_agente_ia — TOPE DE 20 RUTAS
// ============================================================================
// Pedido del usuario (10/11/2026), con todo marcado salieron 33 rutas. El motor elige UNA
// ruta por mensaje leyendo sus descripciones; con muchas, se confunde más (el importador
// de prompts ya las agrupa en ≤ 20: Assistant::BriefTopicGroups::MAX_ROUTES).
// No se resumen solas: cada ruta lleva UNA fuente (y @buscar_predefinidas UN grupo), así
// que unir dos rutas apaga una de ellas. Se avisa y se dice qué tipo de recurso pesa más,
// para que la persona desmarque lo que este agente no necesita.
// ============================================================================
export const MAX_ROUTES = 20;

export default {
  props: {
    // [{ kind }] (las rutas de la vista previa o del agente).
    routes: { type: Array, default: () => [] },
  },
  computed: {
    over() {
      return this.routes.length > MAX_ROUTES;
    },
    byKind() {
      const cuenta = {};
      this.routes.forEach(ruta => {
        if (!ruta.kind) return;
        cuenta[ruta.kind] = (cuenta[ruta.kind] || 0) + 1;
      });
      return Object.entries(cuenta)
        .sort((a, b) => b[1] - a[1])
        .map(([kind, n]) => ({ kind, n }));
    },
  },
  methods: {
    t(key, args) {
      return this.$t(`TRACKING_TEMPLATES.FICHA.${key}`, args);
    },
  },
};
</script>

<template>
  <div
    :class="
      over
        ? 'flex flex-col gap-1.5 px-3 py-2 text-xs rounded-lg bg-amber-50 text-amber-900 dark:bg-amber-900/30 dark:text-amber-100'
        : 'hidden'
    "
  >
    <span v-if="over" class="flex items-center gap-1.5 font-medium">
      <fluent-icon icon="warning" size="14" />
      {{ t('ROUTES_TOO_MANY', { count: routes.length, max: 20 }) }}
    </span>
    <span>{{ t('ROUTES_TOO_MANY_HINT') }}</span>
    <span v-if="byKind.length" class="flex flex-wrap gap-1">
      <span
        v-for="item in byKind"
        :key="item.kind"
        class="px-1.5 py-0.5 rounded bg-white/70 dark:bg-slate-800"
      >
        {{ t(`KIND_${item.kind.toUpperCase()}`) }}: {{ item.n }}
      </span>
    </span>
  </div>
</template>

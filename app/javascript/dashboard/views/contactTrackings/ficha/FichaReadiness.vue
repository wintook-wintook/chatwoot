<script>
// feat/ficha_agente_ia — ¿LISTO PARA ATENDER?
// ============================================================================
// Idea 2 (09/11/2026). La lista de Ficha::Readiness, cada cosa con su arreglo:
//   ✓ OpenAI activo                 ✗ → [Ir a Integraciones]
//   ⚠ Sin canal                      → [Elegir canal]
//   ⚠ Sin datos del negocio          → [✨ Proponer]
//   ⚠ Todavía no atiende             → [Activar en «canal»]   (o, al crear, ☐ activarlo)
// 'fix' lo resuelve la pantalla que lo usa (emit fix); los que llevan a otra sección de
// Configuración abren en otra pestaña para no perder lo capturado.
// ============================================================================
const LINKS = {
  integrations: 'settings/integrations',
  canned: 'settings/canned-response/list',
  knowledge_sources: 'settings/knowledge-sources/list',
};

export default {
  props: {
    items: { type: Array, default: () => [] },
    // Agente nuevo: «activarlo al crear» es una casilla; existente: un botón.
    isNew: { type: Boolean, default: false },
    activateOnCreate: { type: Boolean, default: false },
    canActivate: { type: Boolean, default: false },
    activating: { type: Boolean, default: false },
  },
  emits: ['fix', 'activate', 'update:activateOnCreate'],
  computed: {
    accountId() {
      return this.$route && this.$route.params.accountId;
    },
    readyCount() {
      return this.items.filter(item => item.status === 'ok').length;
    },
  },
  methods: {
    icon(item) {
      if (item.status === 'ok') return 'checkmark-circle';
      return item.status === 'error' ? 'error-circle' : 'warning';
    },
    color(item) {
      if (item.status === 'ok') return 'text-green-700 dark:text-green-300';
      return item.status === 'error'
        ? 'text-red-600'
        : 'text-amber-800 dark:text-amber-200';
    },
    link(item) {
      const ruta = LINKS[item.fix];
      return ruta && this.accountId
        ? `/app/accounts/${this.accountId}/${ruta}`
        : null;
    },
    fixLabel(item) {
      return this.$t(
        `TRACKING_TEMPLATES.FICHA.FIX_${(item.fix || '').toUpperCase()}`
      );
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <span class="text-sm font-medium text-slate-800 dark:text-slate-100">
      {{
        $t('TRACKING_TEMPLATES.FICHA.READY_TITLE', {
          ok: readyCount,
          total: items.length,
        })
      }}
    </span>
    <ul class="!m-0 !p-0 list-none flex flex-col gap-1.5 text-xs">
      <li
        v-for="item in items"
        :key="item.key"
        class="flex flex-col gap-1"
        :data-key="item.key"
      >
        <span class="flex items-start gap-1.5" :class="color(item)">
          <fluent-icon :icon="icon(item)" size="14" class="mt-px shrink-0" />
          {{ item.label }}
        </span>
        <template v-if="item.status !== 'ok' && item.fix">
          <label
            v-if="item.fix === 'activate' && isNew"
            class="flex items-center gap-1.5 !m-0 pl-5 text-slate-600 dark:text-slate-300"
          >
            <input
              type="checkbox"
              class="!m-0"
              :checked="activateOnCreate"
              :disabled="!canActivate"
              @change="$emit('update:activateOnCreate', $event.target.checked)"
            />
            {{ $t('TRACKING_TEMPLATES.FICHA.ACTIVATE_ON_CREATE') }}
          </label>
          <woot-button
            v-else-if="item.fix === 'activate'"
            size="tiny"
            variant="smooth"
            class="self-start ml-5"
            icon="flash-on"
            :is-loading="activating"
            :is-disabled="!canActivate || activating"
            @click="$emit('activate')"
          >
            {{ fixLabel(item) }}
          </woot-button>
          <a
            v-else-if="link(item)"
            :href="link(item)"
            target="_blank"
            rel="noopener noreferrer"
            class="flex items-center gap-1 pl-5 text-woot-600 hover:underline"
          >
            {{ fixLabel(item) }}
            <fluent-icon icon="arrow-right" size="12" />
          </a>
          <woot-button
            v-else
            size="tiny"
            variant="clear"
            class="self-start ml-5"
            @click="$emit('fix', item)"
          >
            {{ fixLabel(item) }}
          </woot-button>
        </template>
      </li>
    </ul>
  </div>
</template>

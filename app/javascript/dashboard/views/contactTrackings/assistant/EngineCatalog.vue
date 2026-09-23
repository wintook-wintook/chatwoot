<script>
// proyecto@asistente_agentes_ia — LO QUE OFRECE EL MOTOR (pestaña Recursos)
// ============================================================================
// Una ficha por cada cosa que el motor sabe hacer —fuentes, acciones, piezas del
// Entrenamiento— con su estado en esta cuenta y los nombres exactos para copiar
// (pedido del usuario, 23/09/2026). La lista y el estado los arma el backend
// (EngineCatalog, desde las tablas del motor); acá solo se dibuja. Los textos de
// cada ficha: TRACKING_ASSISTANT_VIEW.CATALOG_<KEY>_WHAT / _NEEDS.
// ============================================================================
import CopyChip from './CopyChip.vue';

const GROUPS = ['sources', 'actions', 'structure'];
const STATUS_CLASSES = {
  ready: 'bg-green-50 text-green-700 dark:bg-green-900/20 dark:text-green-300',
  missing:
    'bg-amber-50 text-amber-700 dark:bg-amber-900/20 dark:text-amber-300',
  depends: 'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300',
};

export default {
  components: { CopyChip },
  props: {
    catalog: { type: Array, default: () => [] },
  },
  computed: {
    groups() {
      return GROUPS.map(group => ({
        group,
        cards: this.catalog.filter(card => card.group === group),
      })).filter(({ cards }) => cards.length);
    },
  },
  methods: {
    text(card, part) {
      return this.$t(
        `TRACKING_ASSISTANT_VIEW.CATALOG_${card.key.toUpperCase()}_${part}`
      );
    },
    statusClass(status) {
      return STATUS_CLASSES[status] || STATUS_CLASSES.depends;
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-6">
    <section v-for="{ group, cards } in groups" :key="group">
      <h3 class="mb-2 text-sm font-semibold text-slate-800 dark:text-slate-100">
        {{ $t(`TRACKING_ASSISTANT_VIEW.CATALOG_GROUP_${group.toUpperCase()}`) }}
      </h3>
      <div class="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
        <article
          v-for="card in cards"
          :key="card.key"
          class="flex flex-col gap-2 p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-100 dark:border-slate-700"
        >
          <div class="flex flex-wrap items-start justify-between gap-2">
            <CopyChip :text="card.syntax" />
            <span
              class="px-1.5 py-0.5 text-xs rounded"
              :class="statusClass(card.status)"
            >
              {{
                $t(
                  `TRACKING_ASSISTANT_VIEW.CATALOG_STATUS_${card.status.toUpperCase()}`
                )
              }}
            </span>
          </div>
          <p class="!m-0 text-xs text-slate-700 dark:text-slate-200">
            {{ text(card, 'WHAT') }}
          </p>
          <p class="!m-0 text-xs text-slate-500 dark:text-slate-400">
            <span class="font-medium">
              {{ $t('TRACKING_ASSISTANT_VIEW.CATALOG_NEEDS') }}
            </span>
            {{ text(card, 'NEEDS') }}
          </p>
          <div v-if="card.items.length" class="flex flex-col gap-1">
            <span
              class="text-xs font-medium text-slate-500 dark:text-slate-400"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.CATALOG_IN_ACCOUNT') }}
            </span>
            <div class="flex flex-wrap gap-1.5">
              <CopyChip v-for="item in card.items" :key="item" :text="item" />
            </div>
          </div>
        </article>
      </div>
    </section>
  </div>
</template>

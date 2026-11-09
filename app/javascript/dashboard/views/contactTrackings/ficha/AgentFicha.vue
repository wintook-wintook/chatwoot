<script>
// feat/ficha_agente_ia — LOS RECURSOS DE UN AGENTE QUE YA EXISTE
// ============================================================================
// Plan: docs/ficha_agente_ia_plan.md §8–§9. Pedido del usuario (09/11/2026): si cambia la
// ficha, se detecta y se dice qué cambia en el Entrenamiento. Nada se toca sin su OK:
//
//   Agregaste «Precios»: ahora puede contestar datos exactos…      [Agregar ruta]
//   Quitaste «Agenda de Ana», pero la ruta agendar_cita la usa       [Quitar ruta]
//   «PATITAS»: 2 sin vectorizar
//
// Si la ficha nunca se guardó, se muestra la que se lee del Entrenamiento (D2) para
// confirmarla. El chat del Asistente también recibe estos cambios y los menciona.
// ============================================================================
import { useAlert } from 'dashboard/composables';
import FichaAPI from 'dashboard/api/fichaAgente';
import FichaCards from './FichaCards.vue';

const sameItems = (a, b) => JSON.stringify(a) === JSON.stringify(b);

export default {
  components: { FichaCards },
  props: {
    templateId: { type: Number, required: true },
  },
  emits: ['applied', 'changes'],
  data() {
    return {
      cards: [],
      items: [],
      saved: [],
      changes: { added: [], removed: [], not_ready: [], confirmed: true },
      loading: true,
      busy: false,
    };
  },
  computed: {
    dirty() {
      return !sameItems(this.items, this.saved);
    },
    pending() {
      return this.changes.added.length + this.changes.removed.length;
    },
  },
  mounted() {
    this.load();
  },
  methods: {
    t(key, args) {
      return this.$t(`TRACKING_TEMPLATES.FICHA.${key}`, args);
    },
    take(data) {
      this.cards = data.cards || [];
      this.items = JSON.parse(JSON.stringify(data.items || []));
      this.saved = JSON.parse(JSON.stringify(data.items || []));
      this.changes = data.changes || this.changes;
      this.$emit(
        'changes',
        this.changes.added.length + this.changes.removed.length
      );
    },
    async load() {
      this.loading = true;
      try {
        const { data } = await FichaAPI.get(this.templateId);
        this.take(data);
      } catch (error) {
        useAlert(this.t('LOAD_ERROR'));
      } finally {
        this.loading = false;
      }
    },
    async save() {
      this.busy = true;
      try {
        const { data } = await FichaAPI.save(this.templateId, this.items);
        this.take(data);
        useAlert(this.t('SAVED'));
      } catch (error) {
        useAlert(this.t('SAVE_ERROR'));
      } finally {
        this.busy = false;
      }
    },
    async apply({ add = [], remove = [] }) {
      this.busy = true;
      try {
        const { data } = await FichaAPI.apply(this.templateId, { add, remove });
        this.take(data);
        useAlert(this.t('APPLIED'));
        this.$emit('applied');
      } catch (error) {
        const datos = error && error.response && error.response.data;
        useAlert((datos && datos.error) || this.t('APPLY_ERROR'));
      } finally {
        this.busy = false;
      }
    },
    applyAll() {
      this.apply({
        add: this.changes.added.map(item => item.key),
        remove: [...new Set(this.changes.removed.map(item => item.route))],
      });
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0 gap-4">
    <p v-if="loading" class="!m-0 text-sm text-slate-500">
      {{ t('LOADING') }}
    </p>
    <template v-else>
      <div
        v-if="!changes.confirmed"
        class="flex items-center gap-2 px-3 py-2 text-sm rounded-lg shrink-0 bg-woot-25 text-woot-800 dark:bg-woot-900/20 dark:text-woot-100"
      >
        <fluent-icon icon="info" size="16" />
        {{ t('DEDUCED') }}
      </div>

      <!-- Cambios para el Entrenamiento -->
      <section
        v-if="pending || changes.not_ready.length"
        class="flex flex-col gap-2 p-3 border rounded-lg shrink-0 border-amber-200 bg-amber-50/50 dark:border-amber-800 dark:bg-amber-900/10"
      >
        <div class="flex items-center justify-between gap-2">
          <h3
            class="!m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
          >
            {{ t('CHANGES_TITLE') }}
          </h3>
          <woot-button
            v-if="pending > 1"
            size="small"
            icon="checkmark"
            :is-disabled="busy || dirty"
            @click="applyAll"
          >
            {{ t('APPLY_ALL', { count: pending }) }}
          </woot-button>
        </div>
        <p class="!m-0 text-xs text-slate-500">{{ t('CHANGES_HINT') }}</p>
        <ul class="!m-0 !p-0 list-none flex flex-col gap-1.5">
          <li
            v-for="item in changes.added"
            :key="`add-${item.key}`"
            class="flex items-center gap-2 text-sm"
          >
            <fluent-icon icon="add" size="14" class="text-green-700 shrink-0" />
            <span class="flex-1 text-slate-700 dark:text-slate-200">
              {{ t('ADDED', { name: item.name, what: item.label }) }}
            </span>
            <woot-button
              size="tiny"
              variant="smooth"
              :is-disabled="busy || dirty"
              @click="apply({ add: [item.key] })"
            >
              {{ t('ADD_ROUTE') }}
            </woot-button>
          </li>
          <li
            v-for="item in changes.removed"
            :key="`rm-${item.key}-${item.route}`"
            class="flex items-center gap-2 text-sm"
          >
            <fluent-icon
              icon="dismiss"
              size="14"
              class="text-red-600 shrink-0"
            />
            <span class="flex-1 text-slate-700 dark:text-slate-200">
              {{ t('REMOVED', { name: item.name, route: item.route }) }}
            </span>
            <woot-button
              size="tiny"
              variant="smooth"
              color-scheme="alert"
              :is-disabled="busy || dirty"
              @click="apply({ remove: [item.route] })"
            >
              {{ t('REMOVE_ROUTE') }}
            </woot-button>
          </li>
          <li
            v-for="item in changes.not_ready"
            :key="`nr-${item.key}`"
            class="flex items-center gap-2 text-sm text-amber-800 dark:text-amber-200"
          >
            <fluent-icon icon="warning" size="14" class="shrink-0" />
            {{ t('NOT_READY', { name: item.name, why: item.warning }) }}
          </li>
        </ul>
        <p v-if="dirty" class="!m-0 text-xs text-amber-800">
          {{ t('SAVE_FIRST') }}
        </p>
      </section>
      <p
        v-else-if="changes.confirmed && !dirty"
        class="!m-0 flex items-center gap-2 text-sm text-green-700 shrink-0"
      >
        <fluent-icon icon="checkmark-circle" size="16" />
        {{ t('IN_SYNC') }}
      </p>

      <div class="flex-1 min-h-0 pr-1 overflow-auto">
        <FichaCards v-model="items" :cards="cards" :disabled="busy" />
      </div>

      <div
        class="flex items-center justify-end gap-2 pt-3 border-t shrink-0 border-slate-100 dark:border-slate-700"
      >
        <span v-if="dirty" class="text-xs text-slate-500">
          {{ t('UNSAVED') }}
        </span>
        <woot-button
          icon="checkmark"
          :is-loading="busy"
          :is-disabled="busy || (!dirty && changes.confirmed)"
          @click="save"
        >
          {{ changes.confirmed ? t('SAVE') : t('CONFIRM') }}
        </woot-button>
      </div>
    </template>
  </div>
</template>

<script>
// feat/ficha_agente_ia — LOS RECURSOS DE UN AGENTE QUE YA EXISTE
// ============================================================================
// Plan: docs/ficha_agente_ia_plan.md §8–§9. Mismo diseño que al crear (menú · tarjetas ·
// panel). Pedido del usuario (09/11/2026): si cambia la ficha, se detecta y se dice qué
// cambia en el Entrenamiento. Nada se toca sin su OK:
//
//   Agregaste «Precios»: ahora puede contestar datos exactos…      [Agregar ruta]
//   Quitaste «Agenda de Ana», pero la ruta agendar_cita la usa       [Quitar ruta]
//   «PATITAS»: 2 sin vectorizar
//
// Si la ficha nunca se guardó, se muestra la que se lee del Entrenamiento (D2) para
// confirmarla. En Archivos se suben al momento y quedan marcados (y guardados) para que
// el panel proponga mandarlos. El chat del Asistente también recibe estos cambios.
// ============================================================================
import { useAlert } from 'dashboard/composables';
import FichaAPI from 'dashboard/api/fichaAgente';
import FichaCards, { GROUPS } from './FichaCards.vue';
import FichaNav from './FichaNav.vue';
import FichaFiles from './FichaFiles.vue';
import KeywordActionsEditor from 'dashboard/components/contacts/ContactTracking/KeywordActionsEditor.vue';

const SECTIONS = ['sources', 'calendar', 'tickets', 'files', 'rules'];
const SECTION_ICONS = {
  sources: 'library',
  calendar: 'calendar',
  tickets: 'folder',
  files: 'attach',
  rules: 'flash-on',
};
const SOURCE_KINDS = GROUPS.find(group => group.id === 'sources').kinds;
const copy = value => JSON.parse(JSON.stringify(value || []));

export default {
  components: { FichaCards, FichaNav, FichaFiles, KeywordActionsEditor },
  props: {
    templateId: { type: Number, required: true },
  },
  emits: ['applied', 'changes'],
  data() {
    return {
      section: 'sources',
      cards: [],
      items: [],
      saved: [],
      // Reglas (palabras clave → acción): se guardan con la ficha.
      rules: [],
      savedRules: [],
      changes: { added: [], removed: [], not_ready: [], confirmed: true },
      query: '',
      kind: '',
      loading: true,
      busy: false,
    };
  },
  computed: {
    dirty() {
      return (
        JSON.stringify(this.items) !== JSON.stringify(this.saved) ||
        JSON.stringify(this.rules) !== JSON.stringify(this.savedRules)
      );
    },
    pending() {
      return this.changes.added.length + this.changes.removed.length;
    },
    navItems() {
      return SECTIONS.map(id => {
        if (id === 'rules')
          return {
            id,
            icon: SECTION_ICONS[id],
            label: this.t('NAV_RULES'),
            count: this.rules.length,
            total: this.rules.length,
          };
        const grupo = GROUPS.find(group => group.id === id);
        const tarjetas = this.cards.filter(card =>
          grupo.kinds.includes(card.kind)
        );
        const marcadas = tarjetas.filter(card =>
          this.items.some(item => item.key === card.key)
        );
        return {
          id,
          icon: SECTION_ICONS[id],
          label: this.t(`NAV_${id.toUpperCase()}`),
          count: marcadas.length,
          total: tarjetas.length,
        };
      });
    },
    kindChips() {
      return [
        '',
        ...SOURCE_KINDS.filter(kind =>
          this.cards.some(card => card.kind === kind)
        ),
      ];
    },
    fileNames() {
      return this.cards
        .filter(card => card.kind === 'file')
        .map(card => card.name);
    },
  },
  mounted() {
    this.load();
  },
  methods: {
    t(key, args) {
      return this.$t(`TRACKING_TEMPLATES.FICHA.${key}`, args);
    },
    kindLabel(kind) {
      return kind ? this.t(`KIND_${kind.toUpperCase()}`) : this.t('KIND_ALL');
    },
    take(data) {
      this.cards = data.cards || [];
      this.items = copy(data.items);
      this.saved = copy(data.items);
      this.rules = copy(data.keyword_actions);
      this.savedRules = copy(data.keyword_actions);
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
    async save(items = this.items) {
      this.busy = true;
      try {
        const { data } = await FichaAPI.save(this.templateId, items, {
          keyword_actions: this.rules,
        });
        this.take(data);
        useAlert(this.t('SAVED'));
      } catch (error) {
        useAlert(this.t('SAVE_ERROR'));
      } finally {
        this.busy = false;
      }
    },
    // Un archivo recién subido se marca y se guarda: el panel ya propone mandarlo.
    onUploaded(attachment) {
      const llave = `file:${attachment.id}`;
      const marcadas = this.saved.some(item => item.key === llave)
        ? this.saved
        : [...this.saved, { key: llave }];
      this.save(marcadas);
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
  <div class="flex flex-col flex-1 min-h-0 gap-3">
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

      <div
        class="grid flex-1 min-h-0 gap-4 md:grid-cols-[200px_minmax(0,1fr)] xl:grid-cols-[200px_minmax(0,1fr)_320px] xl:grid-rows-[minmax(0,1fr)]"
      >
        <FichaNav v-model="section" :items="navItems" />

        <!-- Sección -->
        <div class="flex flex-col min-h-0 gap-3">
          <!-- Fuentes: buscador y tipos fijos; solo las tarjetas hacen scroll. -->
          <template v-if="section === 'sources'">
            <div class="flex flex-wrap items-center gap-2 shrink-0">
              <div class="relative flex-1 min-w-[12rem]">
                <fluent-icon
                  icon="search"
                  size="14"
                  class="absolute -translate-y-1/2 left-2.5 top-1/2 text-slate-400"
                />
                <input
                  v-model="query"
                  type="search"
                  class="!mb-0 !pl-8 !h-9 text-sm"
                  :placeholder="t('SEARCH')"
                />
              </div>
              <div class="flex flex-wrap gap-1">
                <button
                  v-for="item in kindChips"
                  :key="item || 'all'"
                  type="button"
                  class="px-2.5 py-1 text-xs border rounded-full"
                  :class="
                    kind === item
                      ? 'border-woot-500 bg-woot-500 text-white'
                      : 'border-slate-200 text-slate-600 dark:border-slate-700 dark:text-slate-300'
                  "
                  @click="kind = item"
                >
                  {{ kindLabel(item) }}
                </button>
              </div>
            </div>
            <div class="flex-1 min-h-0 pr-1 overflow-auto">
              <FichaCards
                v-model="items"
                :cards="cards"
                :only="['sources']"
                :query="query"
                :kind="kind"
                :disabled="busy"
                :show-headers="false"
              />
            </div>
          </template>
          <div
            v-else
            class="flex flex-col flex-1 min-h-0 gap-3 pr-1 overflow-auto"
          >
            <template v-if="section === 'files'">
              <p class="!m-0 text-sm text-slate-600 dark:text-slate-300">
                {{ t('FILES_HINT_EXISTING') }}
              </p>
              <FichaFiles
                :template-id="templateId"
                :existing-names="fileNames"
                @uploaded="onUploaded"
              />
              <FichaCards
                v-if="fileNames.length"
                v-model="items"
                :cards="cards"
                :only="['files']"
                :disabled="busy"
                :show-headers="false"
              />
            </template>
            <template v-else-if="section === 'rules'">
              <p class="!m-0 text-sm text-slate-600 dark:text-slate-300">
                {{ t('RULES_HINT') }}
              </p>
              <KeywordActionsEditor v-model="rules" />
            </template>
            <template v-else>
              <p class="!m-0 text-sm text-slate-600 dark:text-slate-300">
                {{ t(`${section.toUpperCase()}_HINT`) }}
              </p>
              <FichaCards
                v-model="items"
                :cards="cards"
                :only="[section]"
                :disabled="busy"
                :show-headers="false"
              />
            </template>
          </div>
        </div>

        <!-- Panel: cambios para el Entrenamiento -->
        <aside
          class="flex flex-col min-h-0 gap-3 p-4 border rounded-lg md:col-span-2 xl:col-span-1 border-slate-200 dark:border-slate-700 bg-slate-25 dark:bg-slate-800/40"
        >
          <h3
            class="!m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
          >
            {{ t('CHANGES_TITLE') }}
          </h3>
          <p v-if="dirty" class="!m-0 text-xs text-amber-800">
            {{ t('SAVE_FIRST') }}
          </p>
          <p
            v-else-if="!pending && !changes.not_ready.length"
            class="!m-0 flex items-center gap-2 text-sm text-green-700"
          >
            <fluent-icon icon="checkmark-circle" size="16" />
            {{ t('IN_SYNC') }}
          </p>
          <template v-else>
            <p class="!m-0 text-xs text-slate-500">{{ t('CHANGES_HINT') }}</p>
            <ul
              class="!m-0 !p-0 list-none flex flex-col gap-2 overflow-auto min-h-0"
            >
              <li
                v-for="item in changes.added"
                :key="`add-${item.key}`"
                class="flex flex-col gap-1 text-sm"
              >
                <span class="flex items-start gap-2">
                  <fluent-icon
                    icon="add"
                    size="14"
                    class="mt-0.5 text-green-700 shrink-0"
                  />
                  <span class="text-slate-700 dark:text-slate-200">
                    {{ t('ADDED', { name: item.name, what: item.label }) }}
                  </span>
                </span>
                <woot-button
                  size="tiny"
                  variant="smooth"
                  class="self-end"
                  :is-disabled="busy"
                  @click="apply({ add: [item.key] })"
                >
                  {{ t('ADD_ROUTE') }}
                </woot-button>
              </li>
              <li
                v-for="item in changes.removed"
                :key="`rm-${item.key}-${item.route}`"
                class="flex flex-col gap-1 text-sm"
              >
                <span class="flex items-start gap-2">
                  <fluent-icon
                    icon="dismiss"
                    size="14"
                    class="mt-0.5 text-red-600 shrink-0"
                  />
                  <span class="text-slate-700 dark:text-slate-200">
                    {{ t('REMOVED', { name: item.name, route: item.route }) }}
                  </span>
                </span>
                <woot-button
                  size="tiny"
                  variant="smooth"
                  color-scheme="alert"
                  class="self-end"
                  :is-disabled="busy"
                  @click="apply({ remove: [item.route] })"
                >
                  {{ t('REMOVE_ROUTE') }}
                </woot-button>
              </li>
              <li
                v-for="item in changes.not_ready"
                :key="`nr-${item.key}`"
                class="flex items-start gap-2 text-sm text-amber-800 dark:text-amber-200"
              >
                <fluent-icon icon="warning" size="14" class="mt-0.5 shrink-0" />
                {{ t('NOT_READY', { name: item.name, why: item.warning }) }}
              </li>
            </ul>
            <woot-button
              v-if="pending > 1"
              size="small"
              icon="checkmark"
              :is-disabled="busy"
              @click="applyAll"
            >
              {{ t('APPLY_ALL', { count: pending }) }}
            </woot-button>
          </template>

          <div class="flex flex-col gap-1 mt-auto">
            <woot-button
              icon="checkmark"
              :is-loading="busy"
              :is-disabled="busy || (!dirty && changes.confirmed)"
              @click="save()"
            >
              {{ changes.confirmed ? t('SAVE') : t('CONFIRM') }}
            </woot-button>
            <span v-if="dirty" class="text-xs text-center text-slate-500">
              {{ t('UNSAVED') }}
            </span>
          </div>
        </aside>
      </div>
    </template>
  </div>
</template>

<!--
  ================================================================================
  proyecto@contact_tracking
  ================================================================================
  Componente: KeywordActionsEditor.vue
  Descripción: Editor de palabras clave de acción para plantillas y seguimientos.
               Permite agregar/editar/eliminar entradas { keyword, action, direction }.
               Las acciones son silenciosas: no generan respuesta al contacto.
               Las acciones "interested" y "booked" suman a los indicadores
               Interesados / Agendaron, aceptan { label, assignee_id, team_id }
               (opcionales) para etiquetar/asignar la conversación y no cortan el flujo.
  ================================================================================
-->
<script>
import { mapGetters } from 'vuex';

const MARK_FIELDS = ['label', 'assignee_id', 'team_id'];
// Acciones que marcan el seguimiento (y aceptan etiqueta/agente/equipo)
const MARK_ACTIONS = ['interested', 'booked'];
// Texto de ayuda: a qué indicador de campaña suma cada acción
const INDICATOR_HINTS = {
  interested: 'HINT_INTERESTED',
  booked: 'HINT_BOOKED',
  objective_met: 'HINT_OBJECTIVE_MET',
};

export default {
  name: 'KeywordActionsEditor',

  // Vue 2: v-model usa prop "value" + evento "input"
  props: {
    value: {
      type: Array,
      default: () => [],
    },
  },

  data() {
    return {
      localItems: this.cloneItems(this.value),
      // Evita que el watcher resetee localItems cuando el propio componente emitió el cambio
      isSelfUpdate: false,
    };
  },

  computed: {
    ...mapGetters({
      labels: 'labels/getLabels',
      agents: 'agents/getAgents',
      teams: 'teams/getTeams',
    }),
  },

  watch: {
    value: {
      handler(newVal) {
        if (this.isSelfUpdate) {
          this.isSelfUpdate = false;
          return;
        }
        // Sincronizar solo cuando el cambio viene del padre (ej: carga de plantilla)
        this.localItems = this.cloneItems(newVal);
      },
      deep: true,
    },
  },

  mounted() {
    if (!this.labels.length) this.$store.dispatch('labels/get');
    if (!this.agents.length) this.$store.dispatch('agents/get');
    if (!this.teams.length) this.$store.dispatch('teams/get');
  },

  methods: {
    cloneItems(items) {
      if (!Array.isArray(items)) return [];
      // Los selects de etiqueta/agente/equipo necesitan '' (no undefined) para la opción vacía
      return items.map(item => {
        const copy = { ...item };
        MARK_FIELDS.forEach(field => {
          if (copy[field] === undefined || copy[field] === null)
            copy[field] = '';
        });
        return copy;
      });
    },

    // Solo interested/booked guardan etiqueta/agente/equipo, y sin los vacíos
    isMarkAction(action) {
      return MARK_ACTIONS.includes(action);
    },

    indicatorHint(action) {
      const key = INDICATOR_HINTS[action];
      return key ? this.$t(`CONTACT_TRACKING.KEYWORD_ACTIONS.MARK.${key}`) : '';
    },

    cleanItem(item) {
      const clean = {
        keyword: item.keyword.trim(),
        action: item.action,
        direction: item.direction,
      };
      if (this.isMarkAction(item.action)) {
        MARK_FIELDS.forEach(field => {
          if (
            item[field] !== '' &&
            item[field] !== undefined &&
            item[field] !== null
          )
            clean[field] = item[field];
        });
      }
      return clean;
    },

    addRow() {
      // Solo agregar la fila visualmente — no emitir (la keyword está vacía todavía)
      this.localItems.push({
        keyword: '',
        action: 'cancel',
        direction: 'incoming',
        label: '',
        assignee_id: '',
        team_id: '',
      });
    },

    removeRow(idx) {
      this.localItems.splice(idx, 1);
      this.emitUpdate();
    },

    emitUpdate() {
      // Marcar que este cambio viene de nosotros para que el watcher no resetee
      this.isSelfUpdate = true;
      const valid = this.localItems.filter(
        item => item.keyword && item.keyword.trim() !== ''
      );
      this.$emit(
        'input',
        valid.map(item => this.cleanItem(item))
      );
    },
  },
};
</script>

<template>
  <div class="keyword-actions-editor">
    <div class="flex items-center justify-between mb-2">
      <div>
        <h4 class="text-sm font-semibold text-slate-700 dark:text-slate-300">
          {{ $t('CONTACT_TRACKING.KEYWORD_ACTIONS.SECTION_TITLE') }}
        </h4>
        <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
          {{ $t('CONTACT_TRACKING.KEYWORD_ACTIONS.SECTION_DESCRIPTION') }}
        </p>
      </div>
      <woot-button
        type="button"
        size="tiny"
        variant="smooth"
        color-scheme="secondary"
        icon="add"
        @click="addRow"
      >
        {{ $t('CONTACT_TRACKING.KEYWORD_ACTIONS.ADD_BTN') }}
      </woot-button>
    </div>

    <!-- Lista vacía -->
    <p
      v-if="localItems.length === 0"
      class="text-xs text-slate-400 dark:text-slate-500 italic py-1"
    >
      {{ $t('CONTACT_TRACKING.KEYWORD_ACTIONS.EMPTY') }}
    </p>

    <!-- Filas -->
    <div v-else class="space-y-2">
      <div v-for="(item, idx) in localItems" :key="idx">
        <div class="flex gap-2 items-center">
          <!-- Palabra clave -->
          <input
            v-model="item.keyword"
            type="text"
            :placeholder="
              $t('CONTACT_TRACKING.KEYWORD_ACTIONS.KEYWORD_PLACEHOLDER')
            "
            class="flex-1 rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 px-3 py-1.5 text-sm focus:outline-none focus:ring-1 focus:ring-woot-500"
            @input="emitUpdate"
          />

          <!-- Acción -->
          <select
            v-model="item.action"
            class="w-44 rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 px-2 py-1.5 text-sm focus:outline-none focus:ring-1 focus:ring-woot-500"
            @change="emitUpdate"
          >
            <option value="cancel">
              {{ $t('CONTACT_TRACKING.KEYWORD_ACTIONS.ACTIONS.CANCEL') }}
            </option>
            <option value="pause">
              {{ $t('CONTACT_TRACKING.KEYWORD_ACTIONS.ACTIONS.PAUSE') }}
            </option>
            <option value="objective_met">
              {{ $t('CONTACT_TRACKING.KEYWORD_ACTIONS.ACTIONS.OBJECTIVE_MET') }}
            </option>
            <option value="interested">
              {{ $t('CONTACT_TRACKING.KEYWORD_ACTIONS.ACTIONS.INTERESTED') }}
            </option>
            <option value="booked">
              {{ $t('CONTACT_TRACKING.KEYWORD_ACTIONS.ACTIONS.BOOKED') }}
            </option>
          </select>

          <!-- Dirección -->
          <select
            v-model="item.direction"
            class="w-40 rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 px-2 py-1.5 text-sm focus:outline-none focus:ring-1 focus:ring-woot-500"
            @change="emitUpdate"
          >
            <option value="incoming">
              {{ $t('CONTACT_TRACKING.KEYWORD_ACTIONS.DIRECTIONS.INCOMING') }}
            </option>
            <option value="outgoing">
              {{ $t('CONTACT_TRACKING.KEYWORD_ACTIONS.DIRECTIONS.OUTGOING') }}
            </option>
            <option value="both">
              {{ $t('CONTACT_TRACKING.KEYWORD_ACTIONS.DIRECTIONS.BOTH') }}
            </option>
          </select>

          <!-- Eliminar -->
          <button
            type="button"
            class="text-slate-400 hover:text-red-500 dark:hover:text-red-400 transition-colors flex-shrink-0"
            :title="$t('CONTACT_TRACKING.KEYWORD_ACTIONS.REMOVE')"
            @click="removeRow(idx)"
          >
            <fluent-icon icon="dismiss" size="16" />
          </button>
        </div>

        <!-- Interesado / Agendó: etiqueta / agente / equipo -->
        <div v-if="isMarkAction(item.action)" class="mt-1.5 ml-4">
          <div class="flex gap-2 items-center">
            <select
              v-model="item.label"
              class="flex-1 rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 px-2 py-1.5 text-sm focus:outline-none focus:ring-1 focus:ring-woot-500"
              @change="emitUpdate"
            >
              <option value="">
                {{ $t('CONTACT_TRACKING.KEYWORD_ACTIONS.MARK.NO_LABEL') }}
              </option>
              <option
                v-for="label in labels"
                :key="label.id"
                :value="label.title"
              >
                {{ label.title }}
              </option>
            </select>
            <select
              v-model="item.assignee_id"
              class="flex-1 rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 px-2 py-1.5 text-sm focus:outline-none focus:ring-1 focus:ring-woot-500"
              @change="emitUpdate"
            >
              <option value="">
                {{ $t('CONTACT_TRACKING.KEYWORD_ACTIONS.MARK.NO_AGENT') }}
              </option>
              <option v-for="agent in agents" :key="agent.id" :value="agent.id">
                {{ agent.name }}
              </option>
            </select>
            <select
              v-model="item.team_id"
              class="flex-1 rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 px-2 py-1.5 text-sm focus:outline-none focus:ring-1 focus:ring-woot-500"
              @change="emitUpdate"
            >
              <option value="">
                {{ $t('CONTACT_TRACKING.KEYWORD_ACTIONS.MARK.NO_TEAM') }}
              </option>
              <option v-for="team in teams" :key="team.id" :value="team.id">
                {{ team.name }}
              </option>
            </select>
          </div>
        </div>

        <!-- A qué indicador de campaña suma -->
        <p
          v-if="indicatorHint(item.action)"
          class="text-xs text-slate-500 dark:text-slate-400 mt-1 ml-4"
        >
          {{ indicatorHint(item.action) }}
        </p>
      </div>
    </div>
  </div>
</template>

<style scoped>
select,
input[type='text'] {
  height: 34px !important;
  font-size: 13px !important;
}

.keyword-actions-editor {
  padding: var(--space-normal);
  background: var(--color-background-light);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-normal);
}
</style>

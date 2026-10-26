<script>
// Embudo de contactos — configuración de una columna: qué tipo de columna es,
// qué hechos de la conversación la meten aquí («Entra aquí cuando…») y el
// criterio en palabras que usa la IA. Trabaja sobre `value` (v-model) con
// entry_triggers, stage_kind, ai_criteria y convert_case_type_id.
import { mapGetters } from 'vuex';
import CaseTypesAPI from 'dashboard/api/caseTypes';
import { creatableTypes } from 'dashboard/helper/caseClasses';

const TRIGGERS = [
  'conversation_created',
  'first_reply',
  'label_added',
  'appointment_scheduled',
  'case_created',
  'conversation_resolved',
];
const KINDS = ['open', 'converted', 'discarded'];
const CASE_CLASSES = ['any', 'commercial', 'support', 'work_order', 'project'];

export default {
  name: 'ColumnFunnelFields',
  props: {
    value: { type: Object, required: true },
  },
  data() {
    return {
      triggerTypes: TRIGGERS,
      kinds: KINDS,
      caseClasses: CASE_CLASSES,
      caseTypes: [],
    };
  },
  computed: {
    ...mapGetters({ labels: 'labels/getLabels' }),
    triggers() {
      return Array.isArray(this.value.entry_triggers)
        ? this.value.entry_triggers
        : [];
    },
    // Las etiquetas de la cuenta más las ya elegidas que la cuenta ya no tenga.
    labelOptions() {
      const titles = this.labels.map(l => l.title);
      const trigger = this.triggerOf('label_added');
      const extra = ((trigger && trigger.labels) || []).filter(
        t => !titles.includes(t)
      );
      return [...titles, ...extra];
    },
    isConverted() {
      return this.value.stage_kind === 'converted';
    },
  },
  watch: {
    isConverted: {
      immediate: true,
      handler(on) {
        if (on && !this.caseTypes.length) this.loadCaseTypes();
      },
    },
  },
  mounted() {
    if (!this.labels.length) this.$store.dispatch('labels/get');
  },
  methods: {
    async loadCaseTypes() {
      try {
        const { data } = await CaseTypesAPI.getAll();
        this.caseTypes = creatableTypes(data.case_types).filter(
          t => t.case_class === 'commercial'
        );
      } catch (e) {
        this.caseTypes = [];
      }
    },
    update(patch) {
      this.$emit('input', { ...this.value, ...patch });
    },
    triggerOf(type) {
      return this.triggers.find(t => t.type === type) || null;
    },
    toggleTrigger(type, on) {
      const rest = this.triggers.filter(t => t.type !== type);
      if (!on) {
        this.update({ entry_triggers: rest });
        return;
      }
      const trigger = { type };
      if (type === 'label_added') trigger.labels = [];
      if (type === 'case_created') trigger.case_class = 'commercial';
      this.update({ entry_triggers: [...rest, trigger] });
    },
    patchTrigger(type, patch) {
      this.update({
        entry_triggers: this.triggers.map(t =>
          t.type === type ? { ...t, ...patch } : t
        ),
      });
    },
    hasLabel(title) {
      const trigger = this.triggerOf('label_added');
      return !!trigger && (trigger.labels || []).includes(title);
    },
    toggleLabel(title) {
      const trigger = this.triggerOf('label_added');
      const current = (trigger && trigger.labels) || [];
      const labels = current.includes(title)
        ? current.filter(l => l !== title)
        : [...current, title];
      this.patchTrigger('label_added', { labels });
    },
  },
};
</script>

<template>
  <div class="w-full mb-4 border-t border-slate-200 dark:border-slate-700 pt-4">
    <label
      class="block mb-1 text-sm font-medium text-slate-700 dark:text-slate-200"
    >
      {{ $t('KANBAN.FUNNEL.COLUMN.KIND') }}
    </label>
    <select
      class="w-full mb-4"
      :value="value.stage_kind || 'open'"
      @change="update({ stage_kind: $event.target.value })"
    >
      <option v-for="kind in kinds" :key="kind" :value="kind">
        {{ $t(`KANBAN.FUNNEL.COLUMN.KINDS.${kind}`) }}
      </option>
    </select>

    <div v-if="isConverted" class="mb-4">
      <label
        class="block mb-1 text-sm font-medium text-slate-700 dark:text-slate-200"
      >
        {{ $t('KANBAN.FUNNEL.COLUMN.CONVERT_TYPE') }}
      </label>
      <select
        class="w-full"
        :value="value.convert_case_type_id || ''"
        @change="update({ convert_case_type_id: $event.target.value || null })"
      >
        <option value="">{{ $t('KANBAN.FUNNEL.COLUMN.CONVERT_NONE') }}</option>
        <option v-for="type in caseTypes" :key="type.id" :value="type.id">
          {{ type.name }}
        </option>
      </select>
    </div>

    <p class="mb-1 text-sm font-medium text-slate-700 dark:text-slate-200">
      {{ $t('KANBAN.FUNNEL.COLUMN.SECTION') }}
    </p>
    <p class="mb-2 text-xs text-slate-500 dark:text-slate-400">
      {{ $t('KANBAN.FUNNEL.COLUMN.SECTION_HELP') }}
    </p>
    <div v-for="type in triggerTypes" :key="type" class="mb-2">
      <label
        class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-200"
      >
        <input
          type="checkbox"
          :checked="!!triggerOf(type)"
          @change="toggleTrigger(type, $event.target.checked)"
        />
        {{ $t(`KANBAN.FUNNEL.COLUMN.TRIGGERS.${type}`) }}
      </label>

      <div
        v-if="type === 'label_added' && triggerOf(type)"
        class="flex flex-wrap gap-1 mt-1 ml-6"
      >
        <span
          v-if="!labelOptions.length"
          class="text-xs text-slate-500 dark:text-slate-400"
        >
          {{ $t('KANBAN.FUNNEL.COLUMN.NO_LABELS') }}
        </span>
        <button
          v-for="title in labelOptions"
          :key="title"
          type="button"
          class="px-2 py-0.5 text-xs rounded-full border"
          :class="
            hasLabel(title)
              ? 'bg-woot-500 text-white border-woot-500'
              : 'border-slate-200 dark:border-slate-700 text-slate-500 dark:text-slate-400'
          "
          @click="toggleLabel(title)"
        >
          {{ title }}
        </button>
      </div>

      <div
        v-if="type === 'case_created' && triggerOf(type)"
        class="flex items-center gap-2 mt-1 ml-6 text-xs text-slate-500 dark:text-slate-400"
      >
        {{ $t('KANBAN.FUNNEL.COLUMN.CASE_CLASS') }}
        <select
          class="!mb-0 !py-1 !h-auto text-xs w-auto"
          :value="triggerOf(type).case_class || 'any'"
          @change="patchTrigger(type, { case_class: $event.target.value })"
        >
          <option v-for="klass in caseClasses" :key="klass" :value="klass">
            {{ $t(`KANBAN.FUNNEL.COLUMN.CASE_CLASSES.${klass}`) }}
          </option>
        </select>
      </div>
    </div>

    <label
      class="block mt-3 mb-1 text-sm font-medium text-slate-700 dark:text-slate-200"
    >
      {{ $t('KANBAN.FUNNEL.COLUMN.AI_CRITERIA') }}
    </label>
    <textarea
      rows="3"
      class="w-full"
      :value="value.ai_criteria || ''"
      :placeholder="$t('KANBAN.FUNNEL.COLUMN.AI_CRITERIA_PLACEHOLDER')"
      @input="update({ ai_criteria: $event.target.value })"
    />
    <p class="text-xs text-slate-500 dark:text-slate-400">
      {{ $t('KANBAN.FUNNEL.COLUMN.AI_CRITERIA_HELP') }}
    </p>
  </div>
</template>

<!--
  Catálogo de plantillas de seguimiento (pestaña de «Cómo habla tu empresa»): las recetas del
  Seguimiento IA. Es la misma lista que «Guardar como plantilla» de la ventana de delegar y
  que usa Dali. Abajo, los ejemplos de arranque: «Agregar a mis plantillas» los copia para
  editarlos. La plantilla de WhatsApp se elige en la ventana de delegar (depende de la
  bandeja); aquí solo se ve y se puede quitar.
-->
<script>
import { useAlert } from 'dashboard/composables';
import AiFollowUpPresetsAPI from 'dashboard/api/aiFollowUpPresets';
import {
  STARTERS,
  STARTER_KEYS,
} from '../gestorTickets/conversation/followUpStarters';

const T = 'AI_VOICE.PRESETS';
const F = 'ASSISTANT.AI_FOLLOW_UP';
const UNITS = ['minutes', 'hours', 'days'];

const blank = () => ({
  id: null,
  name: '',
  objective: '',
  instructions: '',
  max_attempts: 3,
  interval_value: 1,
  interval_unit: 'days',
  on_finish: 'notify',
  template_name: null,
  template_language: null,
});

export default {
  name: 'FollowUpPresets',
  data() {
    return {
      presets: [],
      loading: true,
      editing: null, // la que se edita (o una nueva): copia de sus campos
      saving: false,
      units: UNITS,
    };
  },
  computed: {
    starters() {
      return STARTER_KEYS.map(key => ({
        key,
        ...STARTERS[key],
        name: this.$t(`${F}.STARTERS.${key}.NAME`),
        objective: this.$t(`${F}.STARTERS.${key}.OBJECTIVE`),
        instructions: this.$t(`${F}.STARTERS.${key}.INSTRUCTIONS`),
      }));
    },
  },
  mounted() {
    this.load();
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    f(key, params) {
      return this.$t(`${F}.${key}`, params);
    },
    rhythm(p) {
      return this.t('RHYTHM', {
        n: p.max_attempts,
        every: p.interval_value,
        unit: this.f(`UNITS.${p.interval_unit}`),
      });
    },
    finishLabel(p) {
      return p.on_finish === 'assign'
        ? this.f('ON_FINISH_ASSIGN')
        : this.f('ON_FINISH_NOTIFY');
    },
    async load() {
      try {
        const { data } = await AiFollowUpPresetsAPI.list();
        this.presets = data.payload || [];
      } catch {
        useAlert(this.t('LOAD_ERROR'));
      } finally {
        this.loading = false;
      }
    },
    startNew() {
      this.editing = blank();
    },
    edit(p) {
      this.editing = { ...blank(), ...p };
    },
    // Un ejemplo de arranque: se abre como nueva para ajustarla antes de guardar.
    addStarter(s) {
      const taken = this.presets.some(
        p => p.name.toLowerCase() === s.name.toLowerCase()
      );
      this.editing = {
        ...blank(),
        name: taken ? `${s.name} 2` : s.name,
        objective: s.objective,
        instructions: s.instructions,
        max_attempts: s.max_attempts,
        interval_value: s.interval_value,
        interval_unit: s.interval_unit,
        on_finish: s.on_finish,
      };
    },
    payload() {
      const e = this.editing;
      return {
        name: e.name.trim(),
        objective: e.objective.trim(),
        instructions: (e.instructions || '').trim(),
        max_attempts: Number(e.max_attempts),
        interval_value: Number(e.interval_value),
        interval_unit: e.interval_unit,
        on_finish: e.on_finish,
        template_name: e.template_name || null,
        template_language: e.template_name ? e.template_language : null,
      };
    },
    async save() {
      const e = this.editing;
      if (!e.name.trim() || !e.objective.trim()) {
        useAlert(this.t('NEED_FIELDS'));
        return;
      }
      this.saving = true;
      try {
        if (e.id) await AiFollowUpPresetsAPI.update(e.id, this.payload());
        else await AiFollowUpPresetsAPI.create(this.payload());
        useAlert(this.t('SAVED', { name: e.name.trim() }));
        this.editing = null;
        await this.load();
      } catch (err) {
        useAlert(err.response?.data?.error || this.t('SAVE_ERROR'));
      } finally {
        this.saving = false;
      }
    },
    async remove(p) {
      // eslint-disable-next-line no-alert
      if (!window.confirm(this.f('DELETE_CONFIRM', { name: p.name }))) return;
      try {
        await AiFollowUpPresetsAPI.delete(p.id);
        if (this.editing?.id === p.id) this.editing = null;
        await this.load();
      } catch (err) {
        useAlert(err.response?.data?.error || this.t('SAVE_ERROR'));
      }
    },
  },
};
</script>

<template>
  <div class="grid gap-6 lg:grid-cols-[3fr_2fr] max-w-5xl">
    <section class="flex flex-col gap-3">
      <div class="flex items-center justify-between gap-2">
        <p class="m-0 text-sm text-slate-500 dark:text-slate-400">
          {{ t('HINT') }}
        </p>
        <woot-button
          size="small"
          icon="add"
          data-test="preset-new"
          @click="startNew"
        >
          {{ t('NEW') }}
        </woot-button>
      </div>
      <p v-if="loading" class="text-sm text-slate-500">{{ t('LOADING') }}</p>
      <p
        v-else-if="!presets.length"
        class="m-0 text-sm text-slate-500"
        data-test="preset-empty"
      >
        {{ t('EMPTY') }}
      </p>
      <ul v-else class="flex flex-col gap-2 p-0 m-0 list-none">
        <li
          v-for="p in presets"
          :key="p.id"
          class="flex items-start gap-3 p-3 border rounded-lg border-slate-100 dark:border-slate-700"
          :class="{
            'border-woot-400 dark:border-woot-500':
              editing && editing.id === p.id,
          }"
          data-test="preset-row"
        >
          <div class="flex-1 min-w-0">
            <p class="m-0 font-medium text-slate-800 dark:text-slate-100">
              {{ p.name }}
            </p>
            <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
              {{ p.objective }}
            </p>
            <p class="m-0 mt-1 text-xs text-slate-500 dark:text-slate-400">
              {{ rhythm(p) }} · {{ finishLabel(p) }}
              <span v-if="p.created_by">
                · {{ t('BY', { name: p.created_by }) }}
              </span>
            </p>
          </div>
          <template v-if="p.editable">
            <woot-button
              variant="smooth"
              size="small"
              color-scheme="secondary"
              icon="edit"
              data-test="preset-edit"
              @click="edit(p)"
            />
            <woot-button
              variant="smooth"
              size="small"
              color-scheme="alert"
              icon="delete"
              data-test="preset-delete"
              @click="remove(p)"
            />
          </template>
        </li>
      </ul>

      <h3
        class="m-0 mt-4 text-sm font-semibold text-slate-700 dark:text-slate-200"
      >
        {{ t('EXAMPLES') }}
      </h3>
      <ul class="flex flex-col gap-2 p-0 m-0 list-none">
        <li
          v-for="s in starters"
          :key="s.key"
          class="flex items-start gap-3 p-3 border border-dashed rounded-lg border-slate-200 dark:border-slate-700"
          data-test="preset-starter"
        >
          <div class="flex-1 min-w-0">
            <p class="m-0 font-medium text-slate-700 dark:text-slate-200">
              {{ s.name }}
            </p>
            <p class="m-0 text-sm text-slate-500 dark:text-slate-400">
              {{ s.objective }}
            </p>
            <p class="m-0 mt-1 text-xs text-slate-500 dark:text-slate-400">
              {{ rhythm(s) }} · {{ finishLabel(s) }}
            </p>
          </div>
          <woot-button
            variant="smooth"
            size="small"
            icon="add"
            data-test="preset-add-starter"
            @click="addStarter(s)"
          >
            {{ t('ADD_STARTER') }}
          </woot-button>
        </li>
      </ul>
    </section>

    <aside
      v-if="editing"
      class="flex flex-col gap-3 p-4 border rounded-xl h-fit border-slate-100 dark:border-slate-700 bg-slate-25 dark:bg-slate-800/50"
      data-test="preset-form"
    >
      <h2
        class="m-0 text-base font-semibold text-slate-800 dark:text-slate-100"
      >
        {{ editing.id ? t('EDIT_TITLE') : t('NEW_TITLE') }}
      </h2>
      <label class="flex flex-col gap-1 text-sm">
        {{ t('NAME') }}
        <input
          v-model="editing.name"
          type="text"
          maxlength="80"
          class="!mb-0"
          data-test="preset-name"
          :placeholder="f('PRESET_NAME_PLACEHOLDER')"
        />
      </label>
      <label class="flex flex-col gap-1 text-sm">
        {{ f('OBJECTIVE') }}
        <textarea
          v-model="editing.objective"
          rows="2"
          maxlength="1000"
          class="!mb-0"
          data-test="preset-objective"
          :placeholder="f('OBJECTIVE_PLACEHOLDER')"
        />
      </label>
      <label class="flex flex-col gap-1 text-sm">
        {{ f('INSTRUCTIONS') }}
        <textarea
          v-model="editing.instructions"
          rows="4"
          maxlength="2000"
          class="!mb-0"
          :placeholder="f('INSTRUCTIONS_PLACEHOLDER')"
        />
      </label>
      <div class="flex flex-wrap items-center gap-2 text-sm">
        {{ f('ATTEMPTS') }}
        <input
          v-model="editing.max_attempts"
          type="number"
          min="1"
          max="10"
          class="!mb-0 !w-16"
        />
        {{ f('ATTEMPTS_SUFFIX') }} · {{ f('EVERY') }}
        <input
          v-model="editing.interval_value"
          type="number"
          min="1"
          class="!mb-0 !w-16"
        />
        <select v-model="editing.interval_unit" class="!mb-0 !w-28">
          <option v-for="u in units" :key="u" :value="u">
            {{ f(`UNITS.${u}`) }}
          </option>
        </select>
      </div>
      <label class="flex flex-col gap-1 text-sm">
        {{ f('ON_FINISH') }}
        <select v-model="editing.on_finish" class="!mb-0">
          <option value="notify">{{ f('ON_FINISH_NOTIFY') }}</option>
          <option value="assign">{{ f('ON_FINISH_ASSIGN') }}</option>
        </select>
      </label>
      <p
        v-if="editing.template_name"
        class="flex items-center gap-2 m-0 text-xs text-slate-500 dark:text-slate-400"
      >
        {{ t('WA_TEMPLATE', { name: editing.template_name }) }}
        <button
          type="button"
          class="underline text-woot-600"
          @click="editing.template_name = null"
        >
          {{ t('WA_TEMPLATE_CLEAR') }}
        </button>
      </p>
      <p v-else class="m-0 text-xs text-slate-500 dark:text-slate-400">
        {{ t('WA_TEMPLATE_AUTO') }}
      </p>
      <div class="flex justify-end gap-2">
        <woot-button
          variant="clear"
          color-scheme="secondary"
          @click="editing = null"
        >
          {{ f('CANCEL') }}
        </woot-button>
        <woot-button :is-loading="saving" data-test="preset-save" @click="save">
          {{ t('SAVE') }}
        </woot-button>
      </div>
    </aside>
  </div>
</template>

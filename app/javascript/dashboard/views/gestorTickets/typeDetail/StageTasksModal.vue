<!--
  @tickets_cases — Plan-Plantilla-Tareas-Etapa T1
  Plantilla de tareas de una etapa (columna) del tipo: la lista que nace al
  entrar el caso a la etapa, y qué pasa al terminar las obligatorias. Guarda al
  momento contra la API (no espera a «Guardar columnas»): por eso solo se abre
  en etapas ya guardadas.
-->
<script>
import { mapGetters } from 'vuex';
import CaseTypeColumnsAPI from 'dashboard/api/caseTypeColumns';

const T = 'CASE_TICKETS.COLUMNS_CFG.TASKS';
const PRIORITIES = ['low', 'medium', 'high', 'urgent'];
const ADVANCE_MODES = ['suggest', 'automatic', 'manual'];
const ASSIGNEE_MODES = ['case_assignee', 'user', 'team'];

const emptyForm = () => ({
  id: null,
  title: '',
  description: '',
  required: true,
  dueValue: '',
  dueUnit: 'days',
  priority: 'medium',
  estimated_minutes: '',
  assignee_mode: 'case_assignee',
  assignee_id: '',
  team_id: '',
});

export default {
  name: 'StageTasksModal',
  props: {
    show: { type: Boolean, default: false },
    caseTypeId: { type: Number, required: true },
    column: { type: Object, required: true },
  },
  emits: ['close', 'changed'],
  data() {
    return {
      tasks: [],
      isLoading: false,
      isSaving: false,
      advanceMode: this.column.advance_mode || 'suggest',
      form: null, // null = sin formulario abierto
      priorities: PRIORITIES,
      advanceModes: ADVANCE_MODES,
      assigneeModes: ASSIGNEE_MODES,
    };
  },
  computed: {
    ...mapGetters({ agents: 'agents/getAgents', teams: 'teams/getTeams' }),
    formValid() {
      if (!this.form || !this.form.title.trim()) return false;
      if (this.form.assignee_mode === 'user') return !!this.form.assignee_id;
      if (this.form.assignee_mode === 'team') return !!this.form.team_id;
      return true;
    },
  },
  mounted() {
    if (!this.agents.length) this.$store.dispatch('agents/get');
    if (!this.teams.length) this.$store.dispatch('teams/get');
    this.load();
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    toast(message) {
      this.$emitter.emit('newToastMessage', { message });
    },
    errorOf(e) {
      return (e.response && e.response.data && e.response.data.error) || '';
    },
    async load() {
      this.isLoading = true;
      try {
        const { data } = await CaseTypeColumnsAPI.getTasks(
          this.caseTypeId,
          this.column.id
        );
        this.tasks = data.tasks || [];
      } catch (_e) {
        this.tasks = [];
      } finally {
        this.isLoading = false;
      }
    },
    notify() {
      this.$emit('changed', {
        tasks_count: this.tasks.length,
        required_count: this.tasks.filter(x => x.required).length,
        advance_mode: this.advanceMode,
      });
    },
    async saveAdvanceMode() {
      try {
        await CaseTypeColumnsAPI.updateColumn(this.caseTypeId, this.column.id, {
          advance_mode: this.advanceMode,
        });
        this.notify();
      } catch (e) {
        this.toast(this.errorOf(e) || this.t('SAVE_ERROR'));
      }
    },
    // «Vence» se guarda en horas; en pantalla se elige horas o días.
    dueLabel(task) {
      const h = task.due_after_hours;
      if (h === null || h === undefined) return '';
      if (h % 24 === 0 && h > 0) return this.t('DUE_DAYS', { count: h / 24 });
      return this.t('DUE_HOURS', { count: h });
    },
    assigneeLabel(task) {
      if (task.assignee_mode === 'user') {
        const a = this.agents.find(x => x.id === task.assignee_id);
        return a ? a.name : this.t('ASSIGNEE.user');
      }
      if (task.assignee_mode === 'team') {
        const team = this.teams.find(x => x.id === task.team_id);
        return team ? team.name : this.t('ASSIGNEE.team');
      }
      return this.t('ASSIGNEE.case_assignee');
    },
    openNew() {
      this.form = emptyForm();
    },
    openEdit(task) {
      const h = task.due_after_hours;
      const hasDue = h !== null && h !== undefined;
      const inDays = hasDue && h > 0 && h % 24 === 0;
      let dueValue = '';
      if (hasDue) dueValue = inDays ? h / 24 : h;
      this.form = {
        ...emptyForm(),
        id: task.id,
        title: task.title,
        description: task.description || '',
        required: task.required,
        dueValue,
        dueUnit: inDays ? 'days' : 'hours',
        priority: task.priority,
        estimated_minutes: task.estimated_minutes || '',
        assignee_mode: task.assignee_mode,
        assignee_id: task.assignee_id || '',
        team_id: task.team_id || '',
      };
    },
    payload() {
      const f = this.form;
      const due = f.dueValue === '' ? null : Number(f.dueValue);
      return {
        title: f.title.trim(),
        description: f.description.trim() || null,
        required: f.required,
        due_after_hours:
          due === null
            ? null
            : Math.round(f.dueUnit === 'days' ? due * 24 : due),
        priority: f.priority,
        estimated_minutes:
          f.estimated_minutes === '' ? null : Number(f.estimated_minutes),
        assignee_mode: f.assignee_mode,
        assignee_id: f.assignee_mode === 'user' ? f.assignee_id : null,
        team_id: f.assignee_mode === 'team' ? f.team_id : null,
      };
    },
    async saveForm() {
      if (!this.formValid) return;
      this.isSaving = true;
      try {
        if (this.form.id) {
          const { data } = await CaseTypeColumnsAPI.updateTask(
            this.caseTypeId,
            this.column.id,
            this.form.id,
            this.payload()
          );
          const i = this.tasks.findIndex(x => x.id === data.task.id);
          if (i !== -1) this.tasks.splice(i, 1, data.task);
        } else {
          const { data } = await CaseTypeColumnsAPI.createTask(
            this.caseTypeId,
            this.column.id,
            this.payload()
          );
          this.tasks.push(data.task);
        }
        this.form = null;
        this.notify();
      } catch (e) {
        this.toast(this.errorOf(e) || this.t('SAVE_ERROR'));
      } finally {
        this.isSaving = false;
      }
    },
    async remove(task) {
      try {
        await CaseTypeColumnsAPI.deleteTask(
          this.caseTypeId,
          this.column.id,
          task.id
        );
        this.tasks = this.tasks.filter(x => x.id !== task.id);
        if (this.form && this.form.id === task.id) this.form = null;
        this.notify();
      } catch (e) {
        this.toast(this.errorOf(e) || this.t('SAVE_ERROR'));
      }
    },
    async move(index, delta) {
      const to = index + delta;
      if (to < 0 || to >= this.tasks.length) return;
      const list = [...this.tasks];
      const [item] = list.splice(index, 1);
      list.splice(to, 0, item);
      this.tasks = list;
      try {
        const { data } = await CaseTypeColumnsAPI.reorderTasks(
          this.caseTypeId,
          this.column.id,
          list.map(x => x.id)
        );
        this.tasks = data.tasks || list;
      } catch (e) {
        this.toast(this.errorOf(e) || this.t('SAVE_ERROR'));
        this.load();
      }
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="() => $emit('close')" size="medium">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="t('TITLE', { stage: column.label })"
        :header-content="t('SUBTITLE')"
      />
      <div class="flex flex-col gap-5 px-8 pb-8">
        <!-- Qué pasa al terminar las obligatorias -->
        <label class="flex flex-col gap-1">
          <span class="text-xs font-medium text-slate-600 dark:text-slate-300">
            {{ t('ADVANCE_LABEL') }}
          </span>
          <select v-model="advanceMode" class="!mb-0" @change="saveAdvanceMode">
            <option v-for="m in advanceModes" :key="m" :value="m">
              {{ t(`ADVANCE.${m}`) }}
            </option>
          </select>
          <span class="text-xs text-slate-500 dark:text-slate-400">
            {{ t('ADVANCE_HINT') }}
          </span>
        </label>

        <!-- Lista -->
        <section class="flex flex-col gap-2">
          <div class="flex items-center justify-between">
            <h3
              class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
            >
              {{ t('LIST_TITLE') }}
            </h3>
            <woot-button
              v-if="!form"
              size="small"
              variant="clear"
              icon="add-circle"
              @click="openNew"
            >
              {{ t('ADD') }}
            </woot-button>
          </div>
          <p v-if="isLoading" class="m-0 text-sm text-slate-500">
            {{ t('LOADING') }}
          </p>
          <p
            v-else-if="!tasks.length && !form"
            class="m-0 text-sm text-slate-500 dark:text-slate-400"
          >
            {{ t('EMPTY') }}
          </p>
          <ul v-else class="flex flex-col gap-2 p-0 m-0 list-none">
            <li
              v-for="(task, index) in tasks"
              :key="task.id"
              class="flex items-start gap-2 p-3 border rounded-lg border-slate-200 dark:border-slate-700"
            >
              <div class="flex flex-col">
                <woot-button
                  size="tiny"
                  variant="clear"
                  color-scheme="secondary"
                  icon="chevron-up"
                  :disabled="index === 0"
                  :title="t('MOVE_UP')"
                  @click="move(index, -1)"
                />
                <woot-button
                  size="tiny"
                  variant="clear"
                  color-scheme="secondary"
                  icon="chevron-down"
                  :disabled="index === tasks.length - 1"
                  :title="t('MOVE_DOWN')"
                  @click="move(index, 1)"
                />
              </div>
              <div class="flex flex-col flex-1 min-w-0 gap-1">
                <span
                  class="text-sm font-medium text-slate-800 dark:text-slate-100"
                >
                  {{ task.title }}
                </span>
                <div class="flex flex-wrap gap-1">
                  <span
                    v-if="task.required"
                    class="px-1.5 py-0.5 text-[10px] font-medium rounded-full bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-200"
                  >
                    {{ t('REQUIRED_BADGE') }}
                  </span>
                  <span
                    v-if="dueLabel(task)"
                    class="px-1.5 py-0.5 text-[10px] rounded-full bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
                  >
                    {{ dueLabel(task) }}
                  </span>
                  <span
                    class="px-1.5 py-0.5 text-[10px] rounded-full bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
                  >
                    {{ $t(`CASE_TICKETS.PRIORITIES.${task.priority}`) }}
                  </span>
                  <span
                    class="px-1.5 py-0.5 text-[10px] rounded-full bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
                  >
                    {{ assigneeLabel(task) }}
                  </span>
                  <span
                    v-if="task.estimated_minutes"
                    class="px-1.5 py-0.5 text-[10px] rounded-full bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
                  >
                    {{ t('MINUTES', { count: task.estimated_minutes }) }}
                  </span>
                </div>
              </div>
              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="secondary"
                icon="edit"
                @click="openEdit(task)"
              />
              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="alert"
                icon="delete"
                :title="t('REMOVE')"
                @click="remove(task)"
              />
            </li>
          </ul>
        </section>

        <!-- Alta / edición -->
        <form
          v-if="form"
          class="flex flex-col gap-3 p-4 border rounded-lg border-slate-200 dark:border-slate-700"
          @submit.prevent="saveForm"
        >
          <label class="flex flex-col gap-1">
            <span
              class="text-xs font-medium text-slate-600 dark:text-slate-300"
            >
              {{ t('FIELDS.TITLE') }} *
            </span>
            <input
              v-model="form.title"
              type="text"
              class="!mb-0"
              maxlength="255"
              :placeholder="t('FIELDS.TITLE_PLACEHOLDER')"
            />
          </label>
          <label class="flex flex-col gap-1">
            <span
              class="text-xs font-medium text-slate-600 dark:text-slate-300"
              >{{ t('FIELDS.DESCRIPTION') }}</span
            >
            <textarea v-model="form.description" rows="2" class="!mb-0" />
          </label>
          <div class="grid grid-cols-2 gap-3">
            <label class="flex flex-col gap-1">
              <span
                class="text-xs font-medium text-slate-600 dark:text-slate-300"
                >{{ t('FIELDS.DUE') }}</span
              >
              <div class="flex gap-2">
                <input
                  v-model="form.dueValue"
                  type="number"
                  min="0"
                  class="!w-20 flex-none !mb-0"
                />
                <select v-model="form.dueUnit" class="flex-1 !mb-0">
                  <option value="hours">{{ t('FIELDS.UNIT_HOURS') }}</option>
                  <option value="days">{{ t('FIELDS.UNIT_DAYS') }}</option>
                </select>
              </div>
              <span class="text-[11px] text-slate-500 dark:text-slate-400">
                {{ t('FIELDS.DUE_HINT') }}
              </span>
            </label>
            <label class="flex flex-col gap-1">
              <span
                class="text-xs font-medium text-slate-600 dark:text-slate-300"
                >{{ t('FIELDS.PRIORITY') }}</span
              >
              <select v-model="form.priority" class="!mb-0">
                <option v-for="p in priorities" :key="p" :value="p">
                  {{ $t(`CASE_TICKETS.PRIORITIES.${p}`) }}
                </option>
              </select>
            </label>
            <label class="flex flex-col gap-1">
              <span
                class="text-xs font-medium text-slate-600 dark:text-slate-300"
                >{{ t('FIELDS.ASSIGNEE') }}</span
              >
              <select v-model="form.assignee_mode" class="!mb-0">
                <option v-for="m in assigneeModes" :key="m" :value="m">
                  {{ t(`ASSIGNEE.${m}`) }}
                </option>
              </select>
            </label>
            <label
              v-if="form.assignee_mode === 'user'"
              class="flex flex-col gap-1"
            >
              <span
                class="text-xs font-medium text-slate-600 dark:text-slate-300"
                >{{ t('FIELDS.PERSON') }} *</span
              >
              <select v-model="form.assignee_id" class="!mb-0">
                <option value="">{{ t('FIELDS.CHOOSE') }}</option>
                <option v-for="a in agents" :key="a.id" :value="a.id">
                  {{ a.name }}
                </option>
              </select>
            </label>
            <label
              v-else-if="form.assignee_mode === 'team'"
              class="flex flex-col gap-1"
            >
              <span
                class="text-xs font-medium text-slate-600 dark:text-slate-300"
                >{{ t('FIELDS.TEAM') }} *</span
              >
              <select v-model="form.team_id" class="!mb-0">
                <option value="">{{ t('FIELDS.CHOOSE') }}</option>
                <option v-for="tm in teams" :key="tm.id" :value="tm.id">
                  {{ tm.name }}
                </option>
              </select>
            </label>
            <label class="flex flex-col gap-1">
              <span
                class="text-xs font-medium text-slate-600 dark:text-slate-300"
                >{{ t('FIELDS.MINUTES') }}</span
              >
              <input
                v-model="form.estimated_minutes"
                type="number"
                min="1"
                class="!mb-0"
              />
            </label>
          </div>
          <label class="flex items-center gap-2">
            <input v-model="form.required" type="checkbox" class="!mb-0" />
            <span class="text-sm text-slate-700 dark:text-slate-200">
              {{ t('FIELDS.REQUIRED') }}
            </span>
          </label>
          <div class="flex justify-end gap-2">
            <woot-button
              type="button"
              variant="clear"
              color-scheme="secondary"
              @click="form = null"
            >
              {{ t('CANCEL') }}
            </woot-button>
            <woot-button
              type="submit"
              :is-loading="isSaving"
              :disabled="!formValid"
            >
              {{ form.id ? t('SAVE') : t('ADD') }}
            </woot-button>
          </div>
        </form>

        <div class="flex justify-end">
          <woot-button
            variant="clear"
            color-scheme="secondary"
            @click="$emit('close')"
          >
            {{ t('CLOSE') }}
          </woot-button>
        </div>
      </div>
    </div>
  </woot-modal>
</template>

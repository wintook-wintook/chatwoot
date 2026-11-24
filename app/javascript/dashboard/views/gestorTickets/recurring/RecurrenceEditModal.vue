<!-- Tareas que se repiten — editar: qué, quién, a qué hora, cada cuánto y hasta cuándo. -->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import TaskRecurrencesAPI from 'dashboard/api/taskRecurrences';
import RecurrenceFields from 'dashboard/components/recurrence/RecurrenceFields.vue';
import {
  fromRecurrence,
  recurrencePayload,
} from 'dashboard/components/recurrence/recurrence';

export default {
  name: 'RecurrenceEditModal',
  components: { RecurrenceFields },
  props: {
    recurrence: { type: Object, default: null },
  },
  emits: ['close', 'saved'],
  data() {
    return { form: null, saving: false };
  },
  computed: {
    ...mapGetters({ agents: 'agents/getAgents' }),
  },
  watch: {
    recurrence: {
      immediate: true,
      handler(rec) {
        if (!rec) return;
        this.form = {
          title: rec.title,
          description: rec.description || '',
          assignee_id: rec.assignee ? rec.assignee.id : '',
          at_time: rec.at_time || '',
          starts_on: rec.starts_on,
          cadence: fromRecurrence(rec),
        };
      },
    },
  },
  methods: {
    async save() {
      if (!this.form.title.trim() || this.saving) return;
      this.saving = true;
      try {
        const { data } = await TaskRecurrencesAPI.updateRecurrence(
          this.recurrence.id,
          {
            title: this.form.title.trim(),
            description: this.form.description,
            assignee_id: this.form.assignee_id || undefined,
            at_time: this.form.at_time || null,
            starts_on: this.form.starts_on,
            ...recurrencePayload(this.form.cadence),
          }
        );
        useAlert(this.$t('RECURRING_TASKS.SAVED'));
        this.$emit('saved', data.task_recurrence);
      } catch (error) {
        const reason = error?.response?.data?.error;
        useAlert(
          [].concat(reason || []).join(', ') || this.$t('RECURRING_TASKS.ERROR')
        );
      } finally {
        this.saving = false;
      }
    },
  },
};
</script>

<template>
  <woot-modal :show="!!recurrence" :on-close="() => $emit('close')">
    <woot-modal-header :header-title="$t('RECURRING_TASKS.EDIT_TITLE')" />
    <form
      v-if="form"
      class="flex flex-col gap-3 px-6 pb-6"
      @submit.prevent="save"
    >
      <label class="block">
        <span class="block mb-1 text-xs font-medium text-slate-600">
          {{ $t('QUICK_ACTIONS.TASK.NAME') }}
        </span>
        <input v-model="form.title" type="text" class="!mb-0" />
      </label>
      <label class="block">
        <span class="block mb-1 text-xs font-medium text-slate-600">
          {{ $t('QUICK_ACTIONS.TASK.DESCRIPTION') }}
        </span>
        <textarea v-model="form.description" rows="2" class="!mb-0" />
      </label>
      <div class="grid grid-cols-3 gap-3">
        <label class="block">
          <span class="block mb-1 text-xs font-medium text-slate-600">
            {{ $t('QUICK_ACTIONS.TASK.ASSIGNEE') }}
          </span>
          <select v-model="form.assignee_id" class="!mb-0">
            <option v-for="agent in agents" :key="agent.id" :value="agent.id">
              {{ agent.name }}
            </option>
          </select>
        </label>
        <label class="block">
          <span class="block mb-1 text-xs font-medium text-slate-600">
            {{ $t('RECURRING_TASKS.STARTS') }}
          </span>
          <input v-model="form.starts_on" type="date" class="!mb-0" />
        </label>
        <label class="block">
          <span class="block mb-1 text-xs font-medium text-slate-600">
            {{ $t('RECURRING_TASKS.TIME') }}
          </span>
          <input v-model="form.at_time" type="time" class="!mb-0" />
        </label>
      </div>
      <p class="m-0 -mt-1 text-xs text-slate-500">
        {{ $t('RECURRING_TASKS.TIME_HINT') }}
      </p>
      <RecurrenceFields v-model="form.cadence" />
      <div class="flex justify-end gap-2">
        <woot-button type="button" variant="clear" @click="$emit('close')">
          {{ $t('RECURRING_TASKS.CANCEL') }}
        </woot-button>
        <woot-button type="submit" :is-loading="saving">
          {{ $t('RECURRING_TASKS.SAVE') }}
        </woot-button>
      </div>
    </form>
  </woot-modal>
</template>

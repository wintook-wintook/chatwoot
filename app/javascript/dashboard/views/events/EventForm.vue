<!--
  Plan-Eventos E1 — alta y edición de un evento (panel lateral).
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import EventsAPI from 'dashboard/api/events';
import { KINDS, STATUSES, toLocalInput } from './eventHelpers';

export default {
  name: 'EventForm',
  props: {
    show: { type: Boolean, default: false },
    event: { type: Object, default: null },
  },
  emits: ['close', 'saved'],
  data() {
    return { form: this.blank(), saving: false };
  },
  computed: {
    ...mapGetters({ agents: 'agents/getAgents' }),
    isEdit() {
      return !!(this.event && this.event.id);
    },
    kinds() {
      return KINDS;
    },
    statuses() {
      return STATUSES;
    },
    canSave() {
      return !!this.form.name.trim() && !!this.form.starts_at;
    },
  },
  watch: {
    show: {
      immediate: true,
      handler(open) {
        if (!open) return;
        this.form = this.isEdit
          ? {
              ...this.blank(),
              ...this.event,
              starts_at: toLocalInput(this.event.starts_at),
              ends_at: toLocalInput(this.event.ends_at),
              capacity: this.event.capacity || '',
            }
          : this.blank();
      },
    },
  },
  mounted() {
    this.$store.dispatch('agents/get');
  },
  methods: {
    blank() {
      return {
        name: '',
        kind: 'fair',
        status: 'open',
        starts_at: '',
        ends_at: '',
        location: '',
        meeting_url: '',
        capacity: '',
        description: '',
        owner_id: null,
      };
    },
    payload() {
      const f = this.form;
      const date = value => (value ? new Date(value).toISOString() : null);
      return {
        name: f.name.trim(),
        kind: f.kind,
        status: f.status,
        starts_at: date(f.starts_at),
        ends_at: date(f.ends_at),
        location: f.location,
        meeting_url: f.meeting_url,
        capacity: f.capacity || null,
        description: f.description,
        owner_id: f.owner_id || null,
      };
    },
    async save() {
      if (!this.canSave) return;
      this.saving = true;
      try {
        const { data } = this.isEdit
          ? await EventsAPI.update(this.event.id, this.payload())
          : await EventsAPI.create(this.payload());
        useAlert(this.$t('EVENTS.SAVED'));
        this.$emit('saved', data.event);
      } catch (error) {
        useAlert(error?.response?.data?.error || this.$t('EVENTS.ERROR'));
      } finally {
        this.saving = false;
      }
    },
  },
};
</script>

<template>
  <woot-modal
    :show="show"
    :on-close="() => $emit('close')"
    modal-type="right-aligned"
    size="wide"
  >
    <div class="flex flex-col h-auto">
      <woot-modal-header
        :header-title="
          isEdit ? $t('EVENTS.FORM.EDIT_TITLE') : $t('EVENTS.FORM.NEW_TITLE')
        "
      />
      <form
        class="flex flex-col self-stretch w-full gap-1 px-8 pt-4 pb-0"
        @submit.prevent="save"
      >
        <label>
          {{ $t('EVENTS.FORM.NAME') }}
          <input v-model="form.name" type="text" required maxlength="200" />
        </label>
        <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-2">
          <label>
            {{ $t('EVENTS.FORM.KIND') }}
            <select v-model="form.kind">
              <option v-for="kind in kinds" :key="kind" :value="kind">
                {{ $t(`EVENTS.KINDS.${kind}`) }}
              </option>
            </select>
          </label>
          <label>
            {{ $t('EVENTS.FORM.STATUS') }}
            <select v-model="form.status">
              <option v-for="status in statuses" :key="status" :value="status">
                {{ $t(`EVENTS.STATUSES.${status}`) }}
              </option>
            </select>
          </label>
          <label>
            {{ $t('EVENTS.FORM.STARTS') }}
            <input v-model="form.starts_at" type="datetime-local" required />
          </label>
          <label>
            {{ $t('EVENTS.FORM.ENDS') }}
            <input v-model="form.ends_at" type="datetime-local" />
          </label>
          <label>
            {{ $t('EVENTS.FORM.LOCATION') }}
            <input v-model="form.location" type="text" />
          </label>
          <label>
            {{ $t('EVENTS.FORM.MEETING_URL') }}
            <input v-model="form.meeting_url" type="url" />
          </label>
          <label>
            {{ $t('EVENTS.FORM.CAPACITY') }}
            <input v-model="form.capacity" type="number" min="1" />
          </label>
          <label>
            {{ $t('EVENTS.FORM.OWNER') }}
            <select v-model="form.owner_id">
              <option :value="null">{{ $t('EVENTS.FORM.OWNER_NONE') }}</option>
              <option v-for="agent in agents" :key="agent.id" :value="agent.id">
                {{ agent.name }}
              </option>
            </select>
          </label>
        </div>
        <label>
          {{ $t('EVENTS.FORM.DESCRIPTION') }}
          <textarea v-model="form.description" rows="3" />
        </label>
        <div
          class="sticky bottom-0 z-10 flex justify-end gap-2 px-8 py-3 mt-4 -mx-8 bg-white border-t dark:bg-slate-800 border-slate-50 dark:border-slate-700"
        >
          <button type="button" class="button clear" @click="$emit('close')">
            {{ $t('EVENTS.FORM.CANCEL') }}
          </button>
          <woot-submit-button
            :loading="saving"
            :disabled="!canSave"
            :button-text="$t('EVENTS.FORM.SAVE')"
          />
        </div>
      </form>
    </div>
  </woot-modal>
</template>

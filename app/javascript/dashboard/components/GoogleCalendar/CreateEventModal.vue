<template>
  <woot-modal :show="show" :on-close="onClose">
    <woot-modal-header
      :header-title="isEditing ? $t('GOOGLE_CALENDAR.EDIT_EVENT.TITLE') : $t('GOOGLE_CALENDAR.CREATE_EVENT.TITLE')"
    />
    <form class="p-6 space-y-4" @submit.prevent="submit">
      <woot-input
        v-model="form.summary"
        :label="$t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.SUMMARY')"
        :placeholder="$t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.SUMMARY_PLACEHOLDER')"
        required
      />
      <div class="grid grid-cols-2 gap-4">
        <woot-input
          v-model="form.start_time"
          type="datetime-local"
          :label="$t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.START')"
          required
        />
        <woot-input
          v-model="form.end_time"
          type="datetime-local"
          :label="$t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.END')"
          required
        />
      </div>
      <woot-input
        v-model="form.description"
        :label="$t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.DESCRIPTION')"
        :placeholder="$t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.DESCRIPTION_PLACEHOLDER')"
      />
      <woot-input
        v-model="attendeesInput"
        :label="$t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.ATTENDEES')"
        :placeholder="$t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.ATTENDEES_PLACEHOLDER')"
      />
      <div class="flex justify-end gap-2 pt-2">
        <woot-button variant="clear" @click="onClose">
          {{ $t('GOOGLE_CALENDAR.CREATE_EVENT.CANCEL') }}
        </woot-button>
        <woot-button type="submit" :is-loading="isCreating">
          {{ isEditing ? $t('GOOGLE_CALENDAR.EDIT_EVENT.SUBMIT') : $t('GOOGLE_CALENDAR.CREATE_EVENT.SUBMIT') }}
        </woot-button>
      </div>
    </form>
  </woot-modal>
</template>

<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { format, parseISO } from 'date-fns';

function toDatetimeLocal(isoString) {
  if (!isoString) return '';
  try {
    return format(parseISO(isoString), "yyyy-MM-dd'T'HH:mm");
  } catch {
    return '';
  }
}

export default {
  name: 'CreateEventModal',
  props: {
    show: { type: Boolean, default: false },
    prefillEmail: { type: String, default: '' },
    editEvent: { type: Object, default: null },
  },
  emits: ['close', 'created'],
  setup() {
    const { showAlert } = useAlert();
    return { showAlert };
  },
  data() {
    return {
      form: { summary: '', start_time: '', end_time: '', description: '' },
      attendeesInput: '',
    };
  },
  computed: {
    ...mapGetters({ uiFlags: 'googleCalendar/getCalendarUIFlags' }),
    isCreating() {
      return this.uiFlags.isCreating;
    },
    isEditing() {
      return !!this.editEvent;
    },
  },
  watch: {
    show(val) {
      if (val) this.initForm();
    },
    prefillEmail(val) {
      if (val && !this.isEditing) this.attendeesInput = val;
    },
  },
  methods: {
    initForm() {
      if (this.editEvent) {
        this.form.summary = this.editEvent.title || '';
        this.form.start_time = toDatetimeLocal(this.editEvent.startStr);
        this.form.end_time = toDatetimeLocal(this.editEvent.endStr);
        this.form.description = this.editEvent.extendedProps?.description || '';
        this.attendeesInput = (this.editEvent.extendedProps?.attendees || [])
          .map(a => a.email)
          .join(', ');
      } else {
        this.form = { summary: '', start_time: '', end_time: '', description: '' };
        this.attendeesInput = this.prefillEmail || '';
      }
    },
    async submit() {
      const attendees = this.attendeesInput
        .split(',')
        .map(e => e.trim())
        .filter(Boolean);
      try {
        if (this.isEditing) {
          await this.$store.dispatch('googleCalendar/updateEvent', {
            eventId: this.editEvent.id,
            ...this.form,
            attendees,
          });
          this.showAlert(this.$t('GOOGLE_CALENDAR.EDIT_EVENT.SUCCESS'));
        } else {
          await this.$store.dispatch('googleCalendar/createEvent', {
            ...this.form,
            attendees,
          });
          this.showAlert(this.$t('GOOGLE_CALENDAR.CREATE_EVENT.SUCCESS'));
        }
        this.$emit('created');
        this.onClose();
      } catch {
        this.showAlert(
          this.isEditing
            ? this.$t('GOOGLE_CALENDAR.EDIT_EVENT.ERROR')
            : this.$t('GOOGLE_CALENDAR.CREATE_EVENT.ERROR')
        );
      }
    },
    onClose() {
      this.$emit('close');
    },
  },
};
</script>

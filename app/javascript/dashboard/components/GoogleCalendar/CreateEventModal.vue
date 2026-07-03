<template>
  <woot-modal :show="show" :on-close="onClose">
    <woot-modal-header
      :header-title="modalTitle"
    />

    <div class="px-6 pb-6 space-y-4">
      <!-- Type selector -->
      <div v-if="!isEditing" class="flex rounded-lg border border-slate-200 dark:border-slate-700 overflow-hidden">
        <button
          type="button"
          class="flex-1 flex items-center justify-center gap-1.5 py-2 text-sm font-medium transition-colors"
          :class="form.type === 'event'
            ? 'bg-woot-500 text-white'
            : 'bg-white dark:bg-slate-800 text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700'"
          @click="form.type = 'event'"
        >
          <fluent-icon icon="calendar" size="14" />
          {{ $t('GOOGLE_CALENDAR.CREATE_EVENT.TYPE.EVENT') }}
        </button>
        <button
          type="button"
          class="flex-1 flex items-center justify-center gap-1.5 py-2 text-sm font-medium transition-colors border-l border-slate-200 dark:border-slate-700"
          :class="form.type === 'task'
            ? 'bg-woot-500 text-white'
            : 'bg-white dark:bg-slate-800 text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700'"
          @click="form.type = 'task'"
        >
          <fluent-icon icon="checkmark-circle" size="14" />
          {{ $t('GOOGLE_CALENDAR.CREATE_EVENT.TYPE.TASK') }}
        </button>
      </div>

      <form class="space-y-4" @submit.prevent="submit">
        <!-- Calendar selector (only if the user has more than one writable calendar) -->
        <div v-if="writableCalendars.length > 1" class="space-y-1">
          <label class="block text-sm font-medium text-slate-700 dark:text-slate-200">
            {{ $t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.CALENDAR') }}
          </label>
          <select
            v-model="form.calendar_id"
            :disabled="isEditing"
            class="w-full px-3 py-2 text-sm border rounded-md border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 disabled:opacity-60 disabled:cursor-not-allowed"
          >
            <option
              v-for="cal in writableCalendars"
              :key="cal.id"
              :value="cal.id"
            >
              {{ cal.primary ? $t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.CALENDAR_PRIMARY') : cal.summary }}
            </option>
          </select>
        </div>

        <!-- Title -->
        <woot-input
          v-model="form.summary"
          :label="$t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.SUMMARY')"
          :placeholder="form.type === 'task'
            ? $t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.TASK_PLACEHOLDER')
            : $t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.SUMMARY_PLACEHOLDER')"
          required
        />

        <!-- Event: start + end -->
        <template v-if="form.type === 'event'">
          <!-- All day toggle -->
          <label class="flex items-center gap-2 cursor-pointer w-fit">
            <input
              v-model="form.all_day"
              type="checkbox"
              class="w-4 h-4 rounded accent-woot-500 cursor-pointer"
            />
            <span class="text-sm text-slate-700 dark:text-slate-200">
              {{ $t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.ALL_DAY') }}
            </span>
          </label>

          <!-- With time -->
          <div v-if="!form.all_day" class="grid grid-cols-2 gap-4">
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

          <!-- All day: date range -->
          <div v-else class="grid grid-cols-2 gap-4">
            <woot-input
              v-model="form.start_date"
              type="date"
              :label="$t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.START')"
              required
            />
            <woot-input
              v-model="form.end_date"
              type="date"
              :label="$t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.END')"
              required
            />
          </div>

          <!-- location: pendiente integración Google Maps Places API -->
        </template>

        <!-- Task: single date -->
        <woot-input
          v-else
          v-model="form.due_date"
          type="date"
          :label="$t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.DUE_DATE')"
          required
        />

        <!-- Description / Notes -->
        <woot-input
          v-model="form.description"
          :label="form.type === 'task'
            ? $t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.NOTES')
            : $t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.DESCRIPTION')"
          :placeholder="form.type === 'task'
            ? $t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.NOTES_PLACEHOLDER')
            : $t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.DESCRIPTION_PLACEHOLDER')"
        />

        <!-- Attendees (event only) -->
        <div v-if="form.type === 'event'" class="space-y-1">
          <label class="block text-sm font-medium text-slate-700 dark:text-slate-200">
            {{ $t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.ATTENDEES') }}
          </label>
          <div
            class="flex flex-wrap gap-1.5 min-h-[38px] px-3 py-2 border border-slate-200 dark:border-slate-700 rounded-md bg-white dark:bg-slate-800 cursor-text"
            @click="$refs.attendeeInput.focus()"
          >
            <span
              v-for="email in attendees"
              :key="email"
              class="inline-flex items-center gap-1 bg-woot-50 dark:bg-woot-900 text-woot-700 dark:text-woot-300 text-xs px-2 py-0.5 rounded-full"
            >
              {{ email }}
              <button
                type="button"
                class="hover:text-woot-900 dark:hover:text-woot-100 leading-none"
                @click.stop="removeAttendee(email)"
              >×</button>
            </span>
            <input
              ref="attendeeInput"
              v-model="attendeeInputValue"
              type="text"
              class="flex-1 min-w-[160px] outline-none text-sm bg-transparent text-slate-700 dark:text-slate-200 placeholder-slate-400"
              :placeholder="attendees.length ? '' : $t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.ATTENDEES_PLACEHOLDER')"
              @keydown.enter.prevent="addAttendee"
              @keydown.188.prevent="addAttendee"
              @blur="addAttendee"
            />
          </div>
        </div>

        <div class="flex justify-end gap-2 pt-2">
          <woot-button type="button" variant="clear" @click="onClose">
            {{ $t('GOOGLE_CALENDAR.CREATE_EVENT.CANCEL') }}
          </woot-button>
          <woot-button type="submit" :is-loading="isCreating">
            {{ submitLabel }}
          </woot-button>
        </div>
      </form>
    </div>
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

function toDateLocal(isoString) {
  if (!isoString) return '';
  try {
    return format(parseISO(isoString), 'yyyy-MM-dd');
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
    initialType: { type: String, default: 'event' },
  },
  emits: ['close', 'created'],
  setup() {
    const { showAlert } = useAlert();
    return { showAlert };
  },
  data() {
    return {
      form: {
        type: 'event',
        summary: '',
        calendar_id: 'primary',
        all_day: false,
        start_time: '',
        end_time: '',
        start_date: '',
        end_date: '',
        due_date: '',
        location: '',
        description: '',
      },
      attendees: [],
      attendeeInputValue: '',
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'googleCalendar/getCalendarUIFlags',
      calendars: 'googleCalendar/getCalendars',
    }),
    // Solo los calendarios donde el usuario puede escribir (crear/editar eventos),
    // con el principal primero.
    writableCalendars() {
      return (this.calendars || [])
        .filter(c => !c.access_role || ['owner', 'writer'].includes(c.access_role))
        .slice()
        .sort((a, b) => (b.primary ? 1 : 0) - (a.primary ? 1 : 0));
    },
    // El calendario principal se lista con id = email; normalizamos el alias 'primary' a ese id.
    primaryCalendarId() {
      const primary = this.writableCalendars.find(c => c.primary);
      return primary ? primary.id : 'primary';
    },
    isCreating() {
      return this.uiFlags.isCreating;
    },
    isEditing() {
      return !!this.editEvent;
    },
    modalTitle() {
      if (this.isEditing) return this.$t('GOOGLE_CALENDAR.EDIT_EVENT.TITLE');
      return this.form.type === 'task'
        ? this.$t('GOOGLE_CALENDAR.CREATE_EVENT.TYPE.TASK')
        : this.$t('GOOGLE_CALENDAR.CREATE_EVENT.TITLE');
    },
    submitLabel() {
      if (this.isEditing) return this.$t('GOOGLE_CALENDAR.EDIT_EVENT.SUBMIT');
      return this.form.type === 'task'
        ? this.$t('GOOGLE_CALENDAR.CREATE_EVENT.SUBMIT_TASK')
        : this.$t('GOOGLE_CALENDAR.CREATE_EVENT.SUBMIT');
    },
  },
  watch: {
    show(val) {
      if (val) this.initForm();
    },
    'form.start_date'(val) {
      if (val && !this.form.end_date) this.form.end_date = val;
    },
    prefillEmail(val) {
      if (val && !this.isEditing && !this.attendees.includes(val)) {
        this.attendees = [val];
      }
    },
  },
  methods: {
    initForm() {
      this.form.type = this.initialType || 'event';
      this.attendees = [];
      this.attendeeInputValue = '';

      if (this.editEvent) {
        const isAllDay = this.editEvent.allDay;
        this.form.type = isAllDay ? 'task' : 'event';
        const cid = this.editEvent.extendedProps?.calendarId;
        this.form.calendar_id = !cid || cid === 'primary' ? this.primaryCalendarId : cid;
        this.form.summary = this.editEvent.title || '';
        this.form.start_time = toDatetimeLocal(this.editEvent.startStr);
        this.form.end_time = toDatetimeLocal(this.editEvent.endStr);
        this.form.due_date = toDateLocal(this.editEvent.startStr);
        this.form.description = this.editEvent.extendedProps?.description || '';
        this.form.location = this.editEvent.extendedProps?.location || '';
        this.attendees = (this.editEvent.extendedProps?.attendees || []).map(a => a.email);
      } else {
        this.form.summary = '';
        this.form.calendar_id = this.primaryCalendarId;
        this.form.all_day = false;
        this.form.start_time = '';
        this.form.end_time = '';
        this.form.start_date = '';
        this.form.end_date = '';
        this.form.due_date = '';
        this.form.location = '';
        this.form.description = '';
        if (this.prefillEmail) this.attendees = [this.prefillEmail];
      }
    },
    addAttendee() {
      const email = this.attendeeInputValue.trim().replace(/,$/, '');
      if (!email || !email.includes('@')) return;
      if (!this.attendees.includes(email)) this.attendees.push(email);
      this.attendeeInputValue = '';
    },
    removeAttendee(email) {
      this.attendees = this.attendees.filter(e => e !== email);
    },
    async submit() {
      this.addAttendee();
      const isTask = this.form.type === 'task';
      const payload = isTask
        ? {
            summary: this.form.summary,
            description: this.form.description,
            all_day: true,
            due_date: this.form.due_date,
          }
        : this.form.all_day
        ? {
            summary: this.form.summary,
            description: this.form.description,
            all_day: true,
            due_date: this.form.start_date,
            end_date: this.form.end_date,
            attendees: this.attendees,
          }
        : {
            summary: this.form.summary,
            start_time: this.form.start_time,
            end_time: this.form.end_time,
            description: this.form.description,
            attendees: this.attendees,
          };
      payload.calendar_id = this.form.calendar_id;

      try {
        if (this.isEditing) {
          await this.$store.dispatch('googleCalendar/updateEvent', {
            eventId: this.editEvent.id,
            ...payload,
          });
          this.showAlert(this.$t('GOOGLE_CALENDAR.EDIT_EVENT.SUCCESS'));
        } else {
          await this.$store.dispatch('googleCalendar/createEvent', payload);
          this.showAlert(
            isTask
              ? this.$t('GOOGLE_CALENDAR.CREATE_EVENT.SUCCESS_TASK')
              : this.$t('GOOGLE_CALENDAR.CREATE_EVENT.SUCCESS')
          );
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

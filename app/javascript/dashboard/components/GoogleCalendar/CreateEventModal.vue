<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { format, parseISO } from 'date-fns';
import AgendaItemsAPI from 'dashboard/api/agendaItems';
import OrganizationContactFields from 'dashboard/views/organizations/OrganizationContactFields.vue';

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

// El input datetime-local entrega una hora de pared SIN zona ("2026-06-29T10:00").
// La interpretamos en la zona del navegador (igual que el startStr del drag de
// FullCalendar, que sí funciona) y la enviamos como instante absoluto ISO en UTC.
function toIso(localDatetime) {
  if (!localDatetime) return localDatetime;
  const d = new Date(localDatetime);
  return Number.isNaN(d.getTime()) ? localDatetime : d.toISOString();
}

export default {
  name: 'CreateEventModal',
  components: { OrganizationContactFields },
  props: {
    // Desde una conversación: el contacto ya está elegido.
    prefillContact: { type: Object, default: null },
    show: { type: Boolean, default: false },
    prefillEmail: { type: String, default: '' },
    editEvent: { type: Object, default: null },
    initialStart: { type: String, default: '' },
    initialEnd: { type: String, default: '' },
    initialAllDay: { type: Boolean, default: false },
  },
  emits: ['close', 'created'],
  setup() {
    return { showAlert: useAlert };
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
      // Plan-Agenda — de quién es. «Interno» se queda solo en Google.
      internal: false,
      isVisit: false,
      address: '',
      contact: null,
      organization: null,
      caseId: '',
      cases: [],
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
        .filter(
          c => !c.access_role || ['owner', 'writer'].includes(c.access_role)
        )
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
    agendaItem() {
      return this.editEvent?.extendedProps?.agendaItem || null;
    },
    // Lo que nació en Kontrolya y no está en Google no se edita por la vía de Google.
    isGoogleEvent() {
      return this.isEditing && !String(this.editEvent.id).startsWith('agenda-');
    },
    // En Google todo lo de Kontrolya lleva hora: el de todo el día se queda allá.
    isAllDayEvent() {
      return this.isGoogleEvent && !!this.editEvent.allDay;
    },
    // Tarea agendada de Kontrolya, salvo «Interno».
    isAgenda() {
      return !!this.agendaItem || (!this.internal && !this.isAllDayEvent);
    },
    needsClient() {
      return !this.agendaItem && this.isAgenda;
    },
    canChooseCase() {
      return (
        this.isAgenda &&
        !this.agendaItem?.case_ticket &&
        (this.contact || this.organization)
      );
    },
    showAttendees() {
      return this.form.type === 'event' && !this.agendaItem;
    },
    modalTitle() {
      if (this.isEditing) return this.$t('GOOGLE_CALENDAR.EDIT_EVENT.TITLE');
      return this.form.type === 'task'
        ? this.$t('GOOGLE_CALENDAR.CREATE_EVENT.TYPE.TASK')
        : this.$t('GOOGLE_CALENDAR.CREATE_EVENT.TITLE');
    },
    caseTicket() {
      return this.agendaItem?.case_ticket || null;
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
    contact() {
      this.loadCases();
    },
    internal(val) {
      if (!val) this.form.all_day = false;
    },
    organization() {
      this.loadCases();
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
      this.form.type = 'event';
      this.attendees = [];
      this.attendeeInputValue = '';
      this.internal = false;
      this.isVisit = false;
      this.address = '';
      this.contact = this.agendaItem?.contact || this.prefillContact || null;
      this.organization = this.agendaItem?.organization || null;
      this.caseId = '';
      if (!this.calendars.length) {
        this.$store.dispatch('googleCalendar/fetchCalendars');
      }

      if (this.editEvent) {
        const isAllDay = this.editEvent.allDay;
        this.form.type = isAllDay ? 'task' : 'event';
        const cid = this.editEvent.extendedProps?.calendarId;
        this.form.calendar_id =
          !cid || cid === 'primary' ? this.primaryCalendarId : cid;
        this.form.summary = this.editEvent.title || '';
        this.form.start_time = toDatetimeLocal(this.editEvent.startStr);
        this.form.end_time = toDatetimeLocal(this.editEvent.endStr);
        this.form.due_date = toDateLocal(this.editEvent.startStr);
        this.form.description = this.editEvent.extendedProps?.description || '';
        this.form.location = this.editEvent.extendedProps?.location || '';
        this.attendees = (this.editEvent.extendedProps?.attendees || []).map(
          a => a.email
        );
      } else {
        this.form.summary = '';
        this.form.calendar_id = this.primaryCalendarId;
        this.form.all_day = false;
        this.setInitialTimes();
        this.form.start_date = '';
        this.form.end_date = '';
        this.form.due_date = '';
        this.form.location = '';
        this.form.description = '';
        if (this.prefillEmail) this.attendees = [this.prefillEmail];
      }
      this.loadCases();
    },
    // Clic en la franja de todo el día: siempre lleva hora, se propone de 9 a 10.
    setInitialTimes() {
      if (this.initialStart && this.initialAllDay) {
        const day = toDateLocal(this.initialStart);
        this.form.start_time = `${day}T09:00`;
        this.form.end_time = `${day}T10:00`;
        return;
      }
      this.form.start_time = toDatetimeLocal(this.initialStart);
      this.form.end_time = toDatetimeLocal(this.initialEnd);
    },
    async loadCases() {
      this.caseId = '';
      this.cases = [];
      if (!this.canChooseCase) return;
      try {
        const { data } = await AgendaItemsAPI.cases({
          contact_id: this.contact?.id,
          organization_id:
            this.organization?.id || this.contact?.organization_id,
        });
        this.cases = data.cases;
      } catch {
        this.cases = [];
      }
    },
    openCase() {
      this.$router.push({
        name: 'gestorTickets_detail',
        params: { id: this.caseTicket.id },
      });
      this.onClose();
    },
    itemFields() {
      return {
        title: this.form.summary,
        description: this.form.description,
        starts_at: toIso(this.form.start_time),
        ends_at: toIso(this.form.end_time),
      };
    },
    clientFields() {
      return {
        contact_id: this.contact?.id,
        case_ticket_id: this.caseId || undefined,
      };
    },
    async saveAgendaItem() {
      const { id } = this.agendaItem;
      await AgendaItemsAPI.updateItem(id, this.itemFields());
      if (this.caseId) {
        await AgendaItemsAPI.updateItem(id, { case_ticket_id: this.caseId });
      }
    },
    createAgendaItem() {
      return this.$store.dispatch('googleCalendar/createAgendaItem', {
        calendar_id: this.form.calendar_id,
        attendee_emails: this.attendees,
        is_visit: this.isVisit,
        location: this.address.trim() || undefined,
        ...this.itemFields(),
        ...this.clientFields(),
      });
    },
    // El evento de Google se guarda como está y la tarea nace de él.
    linkGoogleEvent() {
      return this.$store.dispatch('googleCalendar/createAgendaItem', {
        google_event_id: this.editEvent.id,
        calendar_id: this.form.calendar_id,
        ...this.clientFields(),
      });
    },
    async saveAgenda() {
      if (this.agendaItem) {
        await this.saveAgendaItem();
      } else if (this.isGoogleEvent) {
        await this.updateGoogleEvent(this.googlePayload());
        await this.linkGoogleEvent();
      } else {
        await this.createAgendaItem();
      }
    },
    updateGoogleEvent(payload) {
      return this.$store.dispatch('googleCalendar/updateEvent', {
        eventId: this.editEvent.id,
        ...payload,
      });
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
    googlePayload() {
      const isTask = this.form.type === 'task';
      let payload;
      if (isTask) {
        payload = {
          summary: this.form.summary,
          description: this.form.description,
          all_day: true,
          due_date: this.form.due_date,
        };
      } else if (this.form.all_day) {
        payload = {
          summary: this.form.summary,
          description: this.form.description,
          all_day: true,
          due_date: this.form.start_date,
          end_date: this.form.end_date,
          attendees: this.attendees,
        };
      } else {
        payload = {
          summary: this.form.summary,
          start_time: toIso(this.form.start_time),
          end_time: toIso(this.form.end_time),
          description: this.form.description,
          attendees: this.attendees,
        };
      }
      payload.calendar_id = this.form.calendar_id;
      return payload;
    },
    async submit() {
      this.addAttendee();
      if (this.isAgenda && !this.form.summary.trim()) {
        this.showAlert(this.$t('GOOGLE_CALENDAR.AGENDA_LINK.TITLE_REQUIRED'));
        return;
      }
      if (this.needsClient && !this.contact && !this.caseId) {
        this.showAlert(this.$t('GOOGLE_CALENDAR.AGENDA_LINK.CLIENT_REQUIRED'));
        return;
      }
      const isTask = this.form.type === 'task';

      try {
        if (this.isAgenda) {
          await this.saveAgenda();
          this.showAlert(
            this.$t(
              this.isEditing
                ? 'GOOGLE_CALENDAR.EDIT_EVENT.SUCCESS'
                : 'GOOGLE_CALENDAR.CREATE_EVENT.SUCCESS_TASK'
            )
          );
        } else if (this.isEditing) {
          await this.updateGoogleEvent(this.googlePayload());
          this.showAlert(this.$t('GOOGLE_CALENDAR.EDIT_EVENT.SUCCESS'));
        } else {
          await this.$store.dispatch(
            'googleCalendar/createEvent',
            this.googlePayload()
          );
          this.showAlert(
            isTask
              ? this.$t('GOOGLE_CALENDAR.CREATE_EVENT.SUCCESS_TASK')
              : this.$t('GOOGLE_CALENDAR.CREATE_EVENT.SUCCESS')
          );
        }
        this.$emit('created');
        this.onClose();
      } catch (error) {
        // El motivo del servidor, si lo dio (p. ej. «Ese evento ya tiene una tarea»).
        const reason = error?.response?.data?.error;
        this.showAlert(
          [].concat(reason || []).join(', ') ||
            (this.isEditing
              ? this.$t('GOOGLE_CALENDAR.EDIT_EVENT.ERROR')
              : this.$t('GOOGLE_CALENDAR.CREATE_EVENT.ERROR'))
        );
      }
    },
    onClose() {
      this.$emit('close');
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="onClose">
    <woot-modal-header :header-title="modalTitle" />

    <div class="px-6 pb-6 space-y-4">
      <form class="space-y-4" @submit.prevent="submit">
        <!-- Plan-Agenda — de quién es, y en qué caso queda -->
        <div
          v-if="agendaItem"
          class="p-3 space-y-1 text-sm rounded-lg bg-slate-50 dark:bg-slate-800 text-slate-700 dark:text-slate-200"
        >
          <div v-if="agendaItem.contact">
            {{ $t('GOOGLE_CALENDAR.AGENDA_LINK.CONTACT') }}:
            {{ agendaItem.contact.name }}
          </div>
          <div v-if="agendaItem.organization">
            {{ $t('GOOGLE_CALENDAR.AGENDA_LINK.ORGANIZATION') }}:
            {{ agendaItem.organization.name }}
          </div>
          <button
            v-if="caseTicket"
            type="button"
            class="p-0 text-woot-600 hover:underline"
            @click="openCase"
          >
            {{ $t('GOOGLE_CALENDAR.AGENDA_LINK.OPEN_CASE') }}:
            {{ caseTicket.folio }} · {{ caseTicket.title }}
          </button>
        </div>
        <template v-else-if="!isAllDayEvent">
          <p
            v-if="isGoogleEvent"
            class="m-0 text-xs text-amber-700 dark:text-amber-300"
          >
            {{ $t('GOOGLE_CALENDAR.AGENDA_LINK.NO_TASK') }}
          </p>
          <label
            v-if="calendars.length"
            class="flex items-center gap-2 cursor-pointer w-fit"
          >
            <input
              v-model="internal"
              type="checkbox"
              class="w-4 h-4 rounded accent-woot-500 cursor-pointer"
            />
            <span class="text-sm text-slate-700 dark:text-slate-200">
              {{ $t('GOOGLE_CALENDAR.AGENDA_LINK.INTERNAL') }}
            </span>
          </label>
          <OrganizationContactFields
            v-if="!internal"
            v-model="contact"
            :organization.sync="organization"
          />
        </template>
        <div v-if="canChooseCase" class="space-y-1">
          <label
            class="block text-sm font-medium text-slate-700 dark:text-slate-200"
          >
            {{ $t('GOOGLE_CALENDAR.AGENDA_LINK.CASE') }}
          </label>
          <select
            v-model="caseId"
            class="w-full px-3 py-2 text-sm border rounded-md border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200"
          >
            <option value="">
              {{ $t('GOOGLE_CALENDAR.AGENDA_LINK.NO_CASE') }}
            </option>
            <option v-for="item in cases" :key="item.id" :value="item.id">
              {{ item.folio }} · {{ item.title }}
            </option>
          </select>
        </div>

        <!-- Calendar selector (only if the user has more than one writable calendar) -->
        <div v-if="writableCalendars.length > 1" class="space-y-1">
          <label
            class="block text-sm font-medium text-slate-700 dark:text-slate-200"
          >
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
              {{
                cal.primary
                  ? $t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.CALENDAR_PRIMARY')
                  : cal.summary
              }}
            </option>
          </select>
        </div>

        <!-- Title -->
        <woot-input
          v-model="form.summary"
          :label="$t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.SUMMARY')"
          :placeholder="
            form.type === 'task'
              ? $t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.TASK_PLACEHOLDER')
              : $t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.SUMMARY_PLACEHOLDER')
          "
          required
        />

        <!-- Event: start + end -->
        <template v-if="form.type === 'event'">
          <!-- All day toggle: sin hora, lo de Kontrolya es una tarea -->
          <label
            v-if="!isAgenda"
            class="flex items-center gap-2 cursor-pointer w-fit"
          >
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
          :label="
            form.type === 'task'
              ? $t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.NOTES')
              : $t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.DESCRIPTION')
          "
          :placeholder="
            form.type === 'task'
              ? $t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.NOTES_PLACEHOLDER')
              : $t(
                  'GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.DESCRIPTION_PLACEHOLDER'
                )
          "
        />

        <template v-if="isAgenda && !isEditing">
          <label class="flex items-center gap-2 cursor-pointer w-fit">
            <input
              v-model="isVisit"
              type="checkbox"
              class="w-4 h-4 rounded accent-woot-500 cursor-pointer"
            />
            <span class="text-sm text-slate-700 dark:text-slate-200">
              {{ $t('GOOGLE_CALENDAR.AGENDA_LINK.IS_VISIT') }}
            </span>
          </label>
          <woot-input
            v-if="isVisit"
            v-model="address"
            :label="$t('GOOGLE_CALENDAR.AGENDA_LINK.ADDRESS')"
            :placeholder="$t('GOOGLE_CALENDAR.AGENDA_LINK.ADDRESS_PLACEHOLDER')"
          />
        </template>

        <!-- Attendees (event only) -->
        <div v-if="showAttendees" class="space-y-1">
          <label
            class="block text-sm font-medium text-slate-700 dark:text-slate-200"
          >
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
              >
                <fluent-icon icon="dismiss" size="12" />
              </button>
            </span>
            <input
              ref="attendeeInput"
              v-model="attendeeInputValue"
              type="text"
              class="flex-1 min-w-[160px] outline-none text-sm bg-transparent text-slate-700 dark:text-slate-200 placeholder-slate-400"
              :placeholder="
                attendees.length
                  ? ''
                  : $t(
                      'GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.ATTENDEES_PLACEHOLDER'
                    )
              "
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

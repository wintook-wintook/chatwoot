<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { format, parseISO } from 'date-fns';
import AgendaItemsAPI from 'dashboard/api/agendaItems';
import OrganizationContactFields from 'dashboard/views/organizations/OrganizationContactFields.vue';
import ParticipantsPicker from 'dashboard/components/agenda/ParticipantsPicker.vue';
import PeoplePicker from './PeoplePicker.vue';

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
  components: { OrganizationContactFields, ParticipantsPicker, PeoplePicker },
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
  emits: ['close', 'created', 'cancelItem'],
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
      // Agenda: otros del equipo que van (además del responsable).
      participantIds: [],
      declineNote: '',
      declining: false,
      // Plan-Agenda — de quién es. «Interno» se queda solo en Google.
      internal: false,
      isVisit: false,
      address: '',
      contact: null,
      organization: null,
      caseId: '',
      cases: [],
      // Pasarla a tarea sin hora: confirmación en línea.
      toTaskAsk: false,
      toTaskNotify: true,
      toTaskBusy: false,
      // fix/calendario_google F3b — «Agendar a»: '' = para mí; si no, id del compañero.
      scheduleFor: '',
      // fix/calendario_eliminar F3 — «Eliminar evento»: confirmación en línea.
      deleteAsk: false,
      deleteScope: 'one',
      deleteNotify: true,
      deleteBusy: false,
      // feat/ventana_evento_calendario F1 — pestaña abierta y la última al editar (D6).
      activeTab: 'client',
      lastItemTab: null,
      submitTried: false,
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'googleCalendar/getCalendarUIFlags',
      calendars: 'googleCalendar/getCalendars',
      coworkers: 'googleCalendar/getCoworkers',
      agents: 'agents/getAgents',
      currentUserId: 'getCurrentUserID',
    }),
    // F3b — solo compañeros que me dieron «Hacer cambios» en Google (lo vuelve a revisar el servidor).
    scheduleOptions() {
      const names = Object.fromEntries(
        (this.agents || []).map(a => [a.id, a.available_name || a.name])
      );
      return (this.coworkers || [])
        .filter(c => c.can_schedule && names[c.agent_id])
        .map(c => ({ id: c.agent_id, name: names[c.agent_id] }));
    },
    // El campo solo aparece al crear y donde se cargaron los compañeros (pantalla Calendario).
    showScheduleFor() {
      return !this.isEditing && (this.coworkers || []).length > 0;
    },
    schedulingForOther() {
      return !this.isEditing && !!this.scheduleFor;
    },
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
    // fix/calendario_eliminar D2 — al editar dice «Cerrar» para no confundirse con
    // «Cancelar tarea agendada».
    closeLabel() {
      return this.$t(
        this.isEditing
          ? 'GOOGLE_CALENDAR.EDIT_EVENT.CLOSE'
          : 'GOOGLE_CALENDAR.CREATE_EVENT.CANCEL'
      );
    },
    agendaItem() {
      return this.editEvent?.extendedProps?.agendaItem || null;
    },
    // ---- feat/ventana_evento_calendario F1 — cabecera y pestañas ----
    scheduleHint() {
      if (this.schedulingForOther) {
        return this.$t('GOOGLE_CALENDAR.SCHEDULE_FOR.FOR_OTHER_HINT');
      }
      return this.scheduleOptions.length
        ? ''
        : this.$t('GOOGLE_CALENDAR.SCHEDULE_FOR.HINT');
    },
    // Casillas de la pestaña Cliente (van juntas en una fila, debajo del cliente).
    showInternalToggle() {
      return (
        !this.agendaItem && !this.isAllDayEvent && this.calendars.length > 0
      );
    },
    showVisitToggle() {
      return this.isAgenda && !this.isEditing;
    },
    // F2 — agentes como participantes (tarea agendada) o como invitados (solo Google).
    agentsAsParticipants() {
      return this.isAgenda && this.form.type === 'event' && !this.isAllDayEvent;
    },
    // D4 — el cliente se sugiere (no se agrega solo).
    clientSuggestion() {
      const c = this.contact;
      return c && c.email ? { name: c.name, email: c.email } : null;
    },
    showCalendarSelect() {
      return this.writableCalendars.length > 1 && !this.schedulingForOther;
    },
    // H2 — el responsable nunca se ofrece como participante: el de la tarea, el compañero
    // de «Agendar a» o yo.
    participantsOrganizerId() {
      if (this.agendaItem) {
        return this.agendaItem.organizer && this.agendaItem.organizer.id;
      }
      return this.scheduleFor ? Number(this.scheduleFor) : this.currentUserId;
    },
    showClientTab() {
      return !!this.agendaItem || !this.isAllDayEvent || this.canChooseCase;
    },
    showPeopleTab() {
      return (
        this.participating ||
        (this.isAgenda && this.form.type === 'event' && !this.isAllDayEvent) ||
        this.showAttendees
      );
    },
    peopleCount() {
      if (this.participating) {
        return (this.agendaItem.participants || []).length;
      }
      return (this.participantIds || []).length + this.attendees.length;
    },
    clientMissing() {
      return (
        this.submitTried && this.needsClient && !this.contact && !this.caseId
      );
    },
    tabs() {
      const t = key => this.$t(`GOOGLE_CALENDAR.EVENT_TABS.${key}`);
      const list = [];
      if (this.showClientTab) {
        list.push({
          key: 'client',
          label: this.clientMissing ? `${t('CLIENT')} •` : t('CLIENT'),
          count: 0,
        });
      }
      if (this.showPeopleTab) {
        list.push({
          key: 'people',
          label: t('PEOPLE'),
          count: this.peopleCount,
        });
      }
      return list;
    },
    currentTab() {
      if (!this.tabs.length) return null;
      return this.tabs.some(tab => tab.key === this.activeTab)
        ? this.activeTab
        : this.tabs[0].key;
    },
    tabIndex() {
      return this.tabs.findIndex(tab => tab.key === this.currentTab);
    },
    // fix/calendario_eliminar F3 — solo eventos de Google SIN tarea agendada (esas se cancelan)
    // y en calendarios donde puedo hacer cambios (festivos y compartidos «ver» no).
    eventCalendar() {
      const cid = this.editEvent?.extendedProps?.calendarId || 'primary';
      return (this.calendars || []).find(
        c => c.id === cid || (cid === 'primary' && c.primary)
      );
    },
    canDeleteEvent() {
      if (!this.isGoogleEvent || this.agendaItem) return false;
      const role = this.eventCalendar && this.eventCalendar.access_role;
      return !role || ['owner', 'writer'].includes(role);
    },
    // Si me invitaron, solo se quita de MI calendario y no se avisa a nadie.
    isOrganizer() {
      return this.editEvent?.extendedProps?.organizerSelf !== false;
    },
    seriesId() {
      return this.editEvent?.extendedProps?.recurringEventId || null;
    },
    deleteGuests() {
      return (this.editEvent?.extendedProps?.attendees || []).filter(
        a => !a.self
      ).length;
    },
    // Textos de «Eliminar evento» (organizador) o «Quitar de mi calendario» (invitado).
    deleteTexts() {
      const k = `GOOGLE_CALENDAR.DELETE_EVENT.${
        this.isOrganizer ? 'DELETE' : 'REMOVE'
      }`;
      return {
        button: this.$t(k),
        title: this.$t(`${k}_TITLE`, { title: this.form.summary }),
        desc: this.$t(`${k}_DESC`),
        confirm: this.$t(`${k}_CONFIRM`),
        done: this.$t(`${k}_DONE`),
      };
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
    // La ve por ser participante: no la edita; puede decir «No puedo ir».
    participating() {
      return !!this.agendaItem?.participating;
    },
    participantNames() {
      return (this.agendaItem?.participants || []).map(p => p.name).join(', ');
    },
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
    // F3 — también al editar una tarea agendada (si soy el responsable).
    showAttendees() {
      return this.form.type === 'event' && !this.participating;
    },
    modalTitle() {
      // F1 §3.4 — «Editar tarea agendada» o «Editar evento» (solo Google).
      if (this.isEditing) {
        return this.$t(
          this.agendaItem
            ? 'GOOGLE_CALENDAR.EDIT_EVENT.TITLE_ITEM'
            : 'GOOGLE_CALENDAR.EDIT_EVENT.TITLE'
        );
      }
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
      this.participantIds = (this.agendaItem?.participants || []).map(
        p => p.id
      );
      this.declineNote = '';
      this.internal = false;
      this.isVisit = false;
      this.address = '';
      this.contact = this.agendaItem?.contact || this.prefillContact || null;
      this.organization = this.agendaItem?.organization || null;
      this.caseId = '';
      this.scheduleFor = '';
      this.deleteAsk = false;
      this.deleteScope = 'one';
      this.deleteNotify = true;
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
        // F3 — en una tarea agendada solo sus correos invitados (los de Google traen también
        // al organizador y a los participantes).
        this.attendees = this.agendaItem
          ? [...(this.agendaItem.attendee_emails || [])]
          : (this.editEvent.extendedProps?.attendees || []).map(a => a.email);
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
      this.submitTried = false;
      this.activeTab = this.defaultTab();
      this.loadCases();
    },
    // D6 — nueva tarea agendada → Cliente; evento interno o de Google → Personas;
    // editar una tarea agendada → la última pestaña usada en esta sesión.
    defaultTab() {
      if (this.agendaItem) return this.lastItemTab || 'client';
      if (this.isEditing || this.internal) return 'people';
      return 'client';
    },
    selectTab(index) {
      const tab = this.tabs[index];
      if (!tab) return;
      this.activeTab = tab.key;
      if (this.agendaItem) this.lastItemTab = tab.key;
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
        // Quien recibe la tarea ya va como responsable: no se repite como participante.
        participant_ids: (this.participantIds || []).filter(
          id => String(id) !== String(this.scheduleFor)
        ),
      };
    },
    async decline() {
      this.declining = true;
      try {
        await AgendaItemsAPI.decline(this.agendaItem.id, {
          note: this.declineNote.trim() || undefined,
        });
        this.showAlert(this.$t('AGENDA_PARTICIPANTS.CANT_GO_SENT'));
        this.onClose();
      } catch {
        this.showAlert(this.$t('GOOGLE_CALENDAR.CREATE_EVENT.ERROR'));
      } finally {
        this.declining = false;
      }
    },
    clientFields() {
      return {
        contact_id: this.contact?.id,
        case_ticket_id: this.caseId || undefined,
      };
    },
    async saveAgendaItem() {
      const { id } = this.agendaItem;
      await AgendaItemsAPI.updateItem(id, {
        ...this.itemFields(),
        attendee_emails: this.attendees,
      });
      if (this.caseId) {
        await AgendaItemsAPI.updateItem(id, { case_ticket_id: this.caseId });
      }
    },
    createAgendaItem() {
      // Para un compañero: va a SU calendario principal y él queda como responsable.
      const forOther = this.schedulingForOther;
      return this.$store.dispatch('googleCalendar/createAgendaItem', {
        calendar_id: forOther ? 'primary' : this.form.calendar_id,
        assignee_id: forOther ? Number(this.scheduleFor) : undefined,
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
        participant_ids: this.participantIds,
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
    // F2 — lo que quedó escrito en el buscador de Participantes: correos → invitados; si
    // algo no es correo, se abre la pestaña y no se guarda.
    flushPeople() {
      const people = this.$refs && this.$refs.people;
      if (!people || people.flush()) return true;
      this.activeTab = 'people';
      this.showAlert(this.$t('GOOGLE_CALENDAR.PEOPLE.INVALID_SUBMIT'));
      return false;
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
      // F3b — el servidor lo crea en el calendario del compañero (si me dio permiso).
      if (this.schedulingForOther) payload.agent_id = Number(this.scheduleFor);
      return payload;
    },
    async submit() {
      if (!this.flushPeople()) return;
      if (this.isAgenda && !this.form.summary.trim()) {
        this.showAlert(this.$t('GOOGLE_CALENDAR.AGENDA_LINK.TITLE_REQUIRED'));
        return;
      }
      if (this.needsClient && !this.contact && !this.caseId) {
        // F1 — falta algo de otra pestaña: se marca y se abre.
        this.submitTried = true;
        this.activeTab = 'client';
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
      this.toTaskAsk = false;
      this.deleteAsk = false;
      this.$emit('close');
    },
    async deleteEvent() {
      this.deleteBusy = true;
      try {
        await this.$store.dispatch('googleCalendar/deleteEvent', {
          eventId: this.editEvent.id,
          calendar_id: this.editEvent.extendedProps?.calendarId || 'primary',
          scope: this.seriesId ? this.deleteScope : 'one',
          notify:
            this.isOrganizer && this.deleteGuests > 0 && this.deleteNotify,
          seriesId: this.seriesId,
        });
        this.showAlert(this.deleteTexts.done);
        this.$emit('created');
        this.onClose();
      } catch (error) {
        this.showAlert(
          error?.response?.data?.error ||
            this.$t('GOOGLE_CALENDAR.DELETE_EVENT.ERROR')
        );
      } finally {
        this.deleteBusy = false;
      }
    },
    // fix/calendario_eliminar F2 — solo el responsable y mientras siga agendada (realizada,
    // no asistió o cancelada son de solo lectura). El participante tiene «No puedo ir».
    canCancelItem() {
      const item = this.agendaItem;
      return !!item && item.status === 'scheduled' && !item.participating;
    },
    // Tarea agendada → tarea sin hora (Cases::Conversion): sale del calendario y de Google.
    canConvertToTask() {
      const item = this.agendaItem;
      return !!item && item.status === 'scheduled' && !item.work_started;
    },
    async convertToTask() {
      this.toTaskBusy = true;
      try {
        const hasClient = !!(
          this.agendaItem.contact ||
          this.agendaItem.organization ||
          this.agendaItem.case_ticket
        );
        const { data } = await AgendaItemsAPI.toTask(this.agendaItem.id, {
          notify_client: hasClient && this.toTaskNotify,
        });
        this.showAlert(
          this.$t(
            data.mode === 'linked'
              ? 'CONVERT_ITEM.DONE_LINKED'
              : 'CONVERT_ITEM.DONE',
            { title: data.task.title }
          )
        );
        this.$emit('created');
        this.onClose();
      } catch (error) {
        this.showAlert(
          error?.response?.data?.error ||
            this.$t('GOOGLE_CALENDAR.EDIT_EVENT.ERROR')
        );
      } finally {
        this.toTaskBusy = false;
      }
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="onClose" size="medium">
    <woot-modal-header :header-title="modalTitle" />

    <div class="px-6">
      <form class="flex flex-col gap-3" @submit.prevent="submit">
        <!-- feat/ventana_evento_calendario F1 — CABECERA: lo que se llena siempre -->
        <!-- Title -->
        <woot-input
          v-model="form.summary"
          class="[&_input]:!mb-0"
          :label="$t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.SUMMARY')"
          :placeholder="
            form.type === 'task'
              ? $t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.TASK_PLACEHOLDER')
              : $t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.SUMMARY_PLACEHOLDER')
          "
          required
        />
        <!-- Description / Notes -->
        <woot-input
          v-model="form.description"
          class="[&_input]:!mb-0"
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
        <!-- Event: start + end -->
        <template v-if="form.type === 'event'">
          <!-- F1 (H1) — Inicio | Fin | ☐ Todo el día en una sola fila -->
          <div
            class="grid items-end gap-4"
            :class="isAgenda ? 'grid-cols-2' : 'grid-cols-[1fr_1fr_auto]'"
          >
            <label class="block">
              <span class="block mb-1 field-label">
                {{ $t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.START') }}
              </span>
              <input
                v-if="!form.all_day"
                v-model="form.start_time"
                type="datetime-local"
                class="block w-full h-10 px-3 !mb-0 text-sm bg-white border rounded-md border-slate-200 dark:border-slate-700 dark:bg-slate-800 text-slate-700 dark:text-slate-200"
                required
              />
              <input
                v-else
                v-model="form.start_date"
                type="date"
                class="!mb-0"
                required
              />
            </label>
            <label class="block">
              <span class="block mb-1 field-label">
                {{ $t('GOOGLE_CALENDAR.CREATE_EVENT.FIELDS.END') }}
              </span>
              <input
                v-if="!form.all_day"
                v-model="form.end_time"
                type="datetime-local"
                class="block w-full h-10 px-3 !mb-0 text-sm bg-white border rounded-md border-slate-200 dark:border-slate-700 dark:bg-slate-800 text-slate-700 dark:text-slate-200"
                required
              />
              <input
                v-else
                v-model="form.end_date"
                type="date"
                class="!mb-0"
                required
              />
            </label>
            <!-- All day toggle: sin hora, lo de Kontrolya es una tarea -->
            <label
              v-if="!isAgenda"
              class="flex items-center gap-2 pb-2.5 cursor-pointer w-fit"
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
        <div
          v-if="showScheduleFor || showCalendarSelect"
          class="grid grid-cols-1 gap-4 md:grid-cols-2"
        >
          <!-- fix/calendario_google F3b — «Agendar a» un compañero (no queda en mi calendario) -->
          <div v-if="showScheduleFor" class="space-y-1">
            <label
              class="block text-sm font-medium text-slate-700 dark:text-slate-200"
            >
              {{ $t('GOOGLE_CALENDAR.SCHEDULE_FOR.LABEL') }}
            </label>
            <select
              v-model="scheduleFor"
              class="w-full px-3 py-2 text-sm border rounded-md border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200"
            >
              <option value="">
                {{ $t('GOOGLE_CALENDAR.SCHEDULE_FOR.ME') }}
              </option>
              <option
                v-for="option in scheduleOptions"
                :key="option.id"
                :value="String(option.id)"
              >
                {{ option.name }}
              </option>
            </select>
            <!-- F1 — la ayuda solo cuando sirve: agendando a otro, o si nadie me dio permiso -->
            <p
              v-if="scheduleHint"
              class="m-0 text-xs text-slate-500 dark:text-slate-400"
            >
              {{ scheduleHint }}
            </p>
          </div>
          <!-- Calendar selector (only if the user has more than one writable calendar) -->
          <div
            v-if="writableCalendars.length > 1 && !schedulingForOther"
            class="space-y-1"
          >
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
        </div>

        <!-- F1 — pestañas Cliente | Personas: cambia el contenido, la ventana no crece -->
        <template v-if="tabs.length">
          <woot-tabs
            class="w-full"
            :index="tabIndex"
            :border="false"
            @change="selectTab"
          >
            <woot-tabs-item
              v-for="(item, i) in tabs"
              :key="item.key"
              :index="i"
              :name="item.label"
              :count="item.count"
              :show-badge="item.count > 0"
            />
          </woot-tabs>
          <div
            class="h-[210px] overflow-y-auto pr-1"
            data-test="event-tab-body"
          >
            <div
              v-show="currentTab === 'client'"
              class="space-y-4"
              data-test="tab-client"
            >
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
                <OrganizationContactFields
                  v-if="!internal"
                  v-model="contact"
                  :organization.sync="organization"
                  horizontal
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
              <!-- Interno y Es visita en una sola fila, debajo del cliente -->
              <div
                v-if="showInternalToggle || showVisitToggle"
                class="flex flex-wrap items-center gap-x-8 gap-y-2"
              >
                <label
                  v-if="showInternalToggle"
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
                <label
                  v-if="showVisitToggle"
                  class="flex items-center gap-2 cursor-pointer w-fit"
                >
                  <input
                    v-model="isVisit"
                    type="checkbox"
                    class="w-4 h-4 rounded accent-woot-500 cursor-pointer"
                  />
                  <span class="text-sm text-slate-700 dark:text-slate-200">
                    {{ $t('GOOGLE_CALENDAR.AGENDA_LINK.IS_VISIT') }}
                  </span>
                </label>
              </div>
              <woot-input
                v-if="showVisitToggle && isVisit"
                v-model="address"
                :label="$t('GOOGLE_CALENDAR.AGENDA_LINK.ADDRESS')"
                :placeholder="
                  $t('GOOGLE_CALENDAR.AGENDA_LINK.ADDRESS_PLACEHOLDER')
                "
              />
            </div>
            <div
              v-show="currentTab === 'people'"
              class="space-y-4"
              data-test="tab-people"
            >
              <!-- Agenda: participantes (solo el responsable los cambia) -->
              <div
                v-if="participating"
                class="p-3 space-y-2 text-sm rounded-lg bg-woot-50 dark:bg-woot-900/40 text-slate-700 dark:text-slate-200"
              >
                <p class="m-0">
                  {{
                    $t('AGENDA_PARTICIPANTS.ONLY_OWNER', {
                      name: agendaItem.organizer && agendaItem.organizer.name,
                    })
                  }}
                </p>
                <p v-if="participantNames" class="m-0">
                  {{
                    $t('AGENDA_PARTICIPANTS.WITH', { names: participantNames })
                  }}
                </p>
                <input
                  v-model="declineNote"
                  type="text"
                  class="mb-0"
                  :placeholder="$t('AGENDA_PARTICIPANTS.CANT_GO_PROMPT')"
                />
                <woot-button
                  type="button"
                  size="small"
                  color-scheme="alert"
                  variant="smooth"
                  :is-loading="declining"
                  @click="decline"
                >
                  {{ $t('AGENDA_PARTICIPANTS.CANT_GO') }}
                </woot-button>
              </div>
              <template v-else>
                <!-- Agentes: las pastillas de siempre, a la vista (pedido del usuario) -->
                <ParticipantsPicker
                  v-if="agentsAsParticipants"
                  v-model="participantIds"
                  :label="$t('GOOGLE_CALENDAR.PEOPLE.AGENTS')"
                  :organizer-id="participantsOrganizerId"
                  :starts-at="form.start_time"
                  :ends-at="form.end_time"
                  :exclude-id="agendaItem && agendaItem.id"
                  :current="(agendaItem && agendaItem.participants) || []"
                />
                <!-- F2 — Invitados: contactos y correos (con comas, en rojo si están mal) -->
                <PeoplePicker
                  v-if="showAttendees"
                  ref="people"
                  :attendees.sync="attendees"
                  :search-agents="!agentsAsParticipants"
                  :organizer-id="participantsOrganizerId"
                  :client="clientSuggestion"
                />
              </template>
            </div>
          </div>
        </template>

        <!-- Tarea agendada → tarea sin hora -->
        <div
          v-if="toTaskAsk"
          class="flex flex-col gap-2 p-2 text-sm border rounded-md border-slate-200 dark:border-slate-600"
        >
          <p class="m-0 text-slate-700 dark:text-slate-200">
            {{ $t('CONVERT_ITEM.TO_TASK_DESC') }}
          </p>
          <label
            v-if="
              agendaItem.contact ||
              agendaItem.organization ||
              agendaItem.case_ticket
            "
            class="flex items-center gap-2"
          >
            <input v-model="toTaskNotify" type="checkbox" class="!m-0" />
            {{ $t('CONVERT_ITEM.NOTIFY') }}
          </label>
          <div class="flex justify-end gap-2">
            <woot-button
              type="button"
              variant="clear"
              @click="toTaskAsk = false"
            >
              {{ $t('CONVERT_ITEM.CANCEL') }}
            </woot-button>
            <woot-button
              type="button"
              :is-loading="toTaskBusy"
              @click="convertToTask"
            >
              {{ $t('CONVERT_ITEM.CONFIRM') }}
            </woot-button>
          </div>
        </div>

        <!-- fix/calendario_eliminar F3 — eliminar el evento de Google -->
        <div
          v-if="deleteAsk"
          class="flex flex-col gap-2 p-2 text-sm border rounded-md border-red-200 dark:border-red-800"
          data-test="delete-ask"
        >
          <p class="m-0 font-medium text-slate-800 dark:text-slate-100">
            {{ deleteTexts.title }}
          </p>
          <p class="m-0 text-slate-600 dark:text-slate-300">
            {{ deleteTexts.desc }}
          </p>
          <div v-if="seriesId" class="flex gap-4">
            <label class="flex items-center gap-2">
              <input
                v-model="deleteScope"
                type="radio"
                value="one"
                class="!m-0"
              />
              {{ $t('GOOGLE_CALENDAR.DELETE_EVENT.ONLY_THIS') }}
            </label>
            <label class="flex items-center gap-2">
              <input
                v-model="deleteScope"
                type="radio"
                value="all"
                class="!m-0"
              />
              {{ $t('GOOGLE_CALENDAR.DELETE_EVENT.ALL_SERIES') }}
            </label>
          </div>
          <label
            v-if="isOrganizer && deleteGuests > 0"
            class="flex items-center gap-2"
          >
            <input v-model="deleteNotify" type="checkbox" class="!m-0" />
            {{
              $t('GOOGLE_CALENDAR.DELETE_EVENT.NOTIFY', {
                count: deleteGuests,
              })
            }}
          </label>
          <div class="flex justify-end gap-2">
            <woot-button
              type="button"
              variant="clear"
              @click="deleteAsk = false"
            >
              {{ $t('GOOGLE_CALENDAR.DELETE_EVENT.BACK') }}
            </woot-button>
            <woot-button
              type="button"
              color-scheme="alert"
              :is-loading="deleteBusy"
              data-test="delete-confirm"
              @click="deleteEvent"
            >
              {{ deleteTexts.confirm }}
            </woot-button>
          </div>
        </div>

        <div class="flex justify-end gap-2 pt-2">
          <div v-if="!toTaskAsk && !deleteAsk" class="flex gap-2 mr-auto">
            <woot-button
              v-if="canDeleteEvent"
              type="button"
              variant="clear"
              color-scheme="alert"
              data-test="delete-event"
              @click="deleteAsk = true"
            >
              {{ deleteTexts.button }}
            </woot-button>
            <woot-button
              v-if="canCancelItem()"
              type="button"
              variant="clear"
              color-scheme="alert"
              data-test="cancel-item"
              @click="$emit('cancelItem', agendaItem)"
            >
              {{ $t('GOOGLE_CALENDAR.EDIT_EVENT.CANCEL_ITEM') }}
            </woot-button>
            <woot-button
              v-if="canConvertToTask()"
              type="button"
              variant="smooth"
              color-scheme="secondary"
              @click="toTaskAsk = true"
            >
              {{ $t('CONVERT_ITEM.TO_TASK') }}
            </woot-button>
          </div>
          <woot-button type="button" variant="clear" @click="onClose">
            {{ closeLabel }}
          </woot-button>
          <woot-button
            v-if="!participating"
            type="submit"
            :is-loading="isCreating"
          >
            {{ submitLabel }}
          </woot-button>
        </div>
      </form>
    </div>
  </woot-modal>
</template>

<template>
  <woot-modal :show="show" :on-close="onClose" size="medium">
    <woot-modal-header
      :header-title="$t('GOOGLE_CALENDAR.SHARE_AGENDA.TITLE')"
      :header-content="$t('GOOGLE_CALENDAR.SHARE_AGENDA.DESCRIPTION')"
    />

    <div class="px-6 pb-6 space-y-4">
      <!-- Período -->
      <div class="space-y-1">
        <label class="block text-sm font-medium text-slate-700 dark:text-slate-200">
          {{ $t('GOOGLE_CALENDAR.SHARE_AGENDA.PERIOD') }}
        </label>
        <div class="flex gap-2">
          <button
            v-for="opt in periodOptions"
            :key="opt.value"
            type="button"
            class="px-3 py-1.5 text-xs rounded-lg border transition-colors"
            :class="period === opt.value
              ? 'bg-woot-500 text-white border-woot-500'
              : 'border-slate-200 dark:border-slate-600 text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700'"
            @click="period = opt.value"
          >
            {{ opt.label }}
          </button>
        </div>
      </div>

      <!-- Inbox -->
      <div class="space-y-1">
        <label class="block text-sm font-medium text-slate-700 dark:text-slate-200">
          {{ $t('GOOGLE_CALENDAR.SHARE_AGENDA.INBOX') }}
        </label>
        <select
          v-model="selectedInboxId"
          class="w-full text-sm px-3 py-2 border border-slate-200 dark:border-slate-700 rounded-lg bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 outline-none focus:border-woot-400"
        >
          <option value="">{{ $t('GOOGLE_CALENDAR.SHARE_AGENDA.INBOX_PLACEHOLDER') }}</option>
          <option
            v-for="inbox in supportedInboxes"
            :key="inbox.id"
            :value="inbox.id"
          >
            {{ inbox.name }}
          </option>
        </select>
      </div>

      <!-- Contactos -->
      <div class="space-y-1">
        <label class="block text-sm font-medium text-slate-700 dark:text-slate-200">
          {{ $t('GOOGLE_CALENDAR.SHARE_AGENDA.CONTACTS') }}
        </label>

        <!-- Tags de contactos seleccionados -->
        <div
          v-if="selectedContacts.length"
          class="flex flex-wrap gap-1.5 mb-2"
        >
          <span
            v-for="contact in selectedContacts"
            :key="contact.id"
            class="inline-flex items-center gap-1 bg-woot-50 dark:bg-woot-900 text-woot-700 dark:text-woot-300 text-xs px-2 py-0.5 rounded-full"
          >
            {{ contact.name }}
            <button type="button" class="hover:text-woot-900" @click="removeContact(contact.id)">×</button>
          </span>
        </div>

        <!-- Búsqueda -->
        <div class="relative">
          <input
            v-model="contactSearch"
            type="text"
            class="w-full text-sm px-3 py-2 border border-slate-200 dark:border-slate-700 rounded-lg bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 outline-none focus:border-woot-400"
            :placeholder="$t('GOOGLE_CALENDAR.SHARE_AGENDA.CONTACTS_PLACEHOLDER')"
            @input="debouncedSearch"
            @focus="showContactResults = true"
          />
          <div
            v-if="showContactResults && contactResults.length"
            class="absolute z-20 w-full top-full mt-1 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg shadow-lg max-h-40 overflow-y-auto"
          >
            <button
              v-for="contact in contactResults"
              :key="contact.id"
              type="button"
              class="w-full flex items-center gap-2 px-3 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700 text-left"
              @mousedown.prevent="selectContact(contact)"
            >
              <img
                v-if="contact.thumbnail"
                :src="contact.thumbnail"
                class="w-6 h-6 rounded-full object-cover flex-shrink-0"
              />
              <span
                v-else
                class="w-6 h-6 rounded-full bg-woot-100 text-woot-600 text-xs flex items-center justify-center flex-shrink-0 font-medium"
              >
                {{ contact.name[0] }}
              </span>
              <div class="min-w-0">
                <p class="truncate font-medium">{{ contact.name }}</p>
                <p class="text-xs text-slate-400 truncate">{{ contact.email || contact.phone_number }}</p>
              </div>
            </button>
          </div>
        </div>
      </div>

      <!-- Preview del mensaje -->
      <div v-if="periodEvents.length" class="space-y-1">
        <label class="block text-sm font-medium text-slate-700 dark:text-slate-200">
          {{ $t('GOOGLE_CALENDAR.SHARE_AGENDA.PREVIEW') }}
        </label>
        <pre class="text-xs bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg p-3 whitespace-pre-wrap text-slate-600 dark:text-slate-300 max-h-36 overflow-y-auto font-sans">{{ messagePreview }}</pre>
      </div>

      <div class="flex justify-end gap-2 pt-2">
        <woot-button type="button" variant="clear" @click="onClose">
          {{ $t('GOOGLE_CALENDAR.SHARE_AGENDA.CANCEL') }}
        </woot-button>
        <woot-button
          :is-loading="sending"
          :disabled="!canSend"
          @click="send"
        >
          {{ $t('GOOGLE_CALENDAR.SHARE_AGENDA.SEND') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>

<script>
import { mapGetters } from 'vuex';
import { format, parseISO, addDays, startOfDay, endOfDay } from 'date-fns';
import { es } from 'date-fns/locale';
import { useAlert } from 'dashboard/composables';
import ContactsAPI from 'dashboard/api/contacts';

const SUPPORTED_CHANNEL_TYPES = [
  'Channel::WebWidget',
  'Channel::Api',
  'Channel::Email',
  'Channel::Whatsapp',
  'Channel::Sms',
  'Channel::TwilioSms',
  'Channel::Telegram',
  'Channel::Line',
  'Channel::Instagram',
  'Channel::Facebook',
];

export default {
  name: 'ShareAgendaModal',
  props: {
    show: { type: Boolean, default: false },
  },
  emits: ['close'],
  data() {
    return {
      period: 0,
      selectedInboxId: '',
      selectedContacts: [],
      contactSearch: '',
      contactResults: [],
      showContactResults: false,
      sending: false,
      searchTimeout: null,
    };
  },
  computed: {
    ...mapGetters({
      events: 'googleCalendar/getCalendarEvents',
      inboxes: 'inboxes/getInboxes',
    }),
    periodOptions() {
      return [
        { value: 0,  label: this.$t('GOOGLE_CALENDAR.SHARE_AGENDA.TODAY') },
        { value: 3,  label: this.$t('GOOGLE_CALENDAR.SHARE_AGENDA.DAYS_3') },
        { value: 7,  label: this.$t('GOOGLE_CALENDAR.SHARE_AGENDA.DAYS_7') },
      ];
    },
    supportedInboxes() {
      return this.inboxes.filter(i => SUPPORTED_CHANNEL_TYPES.includes(i.channel_type));
    },
    periodEvents() {
      const now = new Date();
      const end = this.period === 0 ? endOfDay(now) : endOfDay(addDays(now, this.period));
      return this.events.filter(e => {
        const start = e.start?.dateTime || e.start?.date;
        if (!start) return false;
        const d = new Date(start);
        return d >= startOfDay(now) && d <= end;
      }).sort((a, b) => {
        const aDate = a.start?.dateTime || a.start?.date || '';
        const bDate = b.start?.dateTime || b.start?.date || '';
        return aDate.localeCompare(bDate);
      });
    },
    canSend() {
      return this.periodEvents.length > 0 &&
        this.selectedInboxId &&
        this.selectedContacts.length > 0;
    },
    messagePreview() {
      if (!this.periodEvents.length) return '';
      const grouped = {};
      this.periodEvents.forEach(e => {
        const dateKey = e.start?.date || (e.start?.dateTime ? e.start.dateTime.slice(0, 10) : '');
        if (!grouped[dateKey]) grouped[dateKey] = [];
        grouped[dateKey].push(e);
      });

      const lines = ['📅 Mi agenda:\n'];
      Object.keys(grouped).sort().forEach(dateKey => {
        try {
          const d = parseISO(dateKey);
          lines.push(`\n${format(d, "EEEE d 'de' MMMM", { locale: es })}`);
        } catch {
          lines.push(`\n${dateKey}`);
        }
        grouped[dateKey].forEach(event => {
          const timeStr = event.start?.dateTime
            ? `${format(parseISO(event.start.dateTime), 'HH:mm')} – ${format(parseISO(event.end.dateTime), 'HH:mm')}`
            : '(Todo el día)';
          lines.push(`  • ${timeStr}  ${event.summary || 'Sin título'}`);
        });
      });
      return lines.join('\n');
    },
  },
  watch: {
    show(val) {
      if (val) this.initForm();
    },
  },
  methods: {
    initForm() {
      this.period = 0;
      this.selectedInboxId = '';
      this.selectedContacts = [];
      this.contactSearch = '';
      this.contactResults = [];
    },
    debouncedSearch() {
      clearTimeout(this.searchTimeout);
      this.searchTimeout = setTimeout(() => this.searchContacts(), 300);
    },
    async searchContacts() {
      if (!this.contactSearch.trim()) {
        this.contactResults = [];
        return;
      }
      try {
        const { data } = await ContactsAPI.search(this.contactSearch, 1);
        this.contactResults = (data.payload || [])
          .filter(c => !this.selectedContacts.find(s => s.id === c.id))
          .slice(0, 8);
      } catch {
        this.contactResults = [];
      }
    },
    selectContact(contact) {
      if (!this.selectedContacts.find(c => c.id === contact.id)) {
        this.selectedContacts.push(contact);
      }
      this.contactSearch = '';
      this.contactResults = [];
      this.showContactResults = false;
    },
    removeContact(id) {
      this.selectedContacts = this.selectedContacts.filter(c => c.id !== id);
    },
    async send() {
      if (!this.canSend) return;
      this.sending = true;
      try {
        const events = this.periodEvents.map(e => ({
          summary:    e.summary,
          all_day:    !e.start?.dateTime,
          start_date: e.start?.date || e.start?.dateTime?.slice(0, 10),
          start_time: e.start?.dateTime || null,
          end_time:   e.end?.dateTime   || null,
        }));

        await this.$store.dispatch('googleCalendar/shareAgenda', {
          events,
          inbox_id:    this.selectedInboxId,
          contact_ids: this.selectedContacts.map(c => c.id),
        });

        useAlert(this.$t('GOOGLE_CALENDAR.SHARE_AGENDA.SUCCESS'));
        this.onClose();
      } catch {
        useAlert(this.$t('GOOGLE_CALENDAR.SHARE_AGENDA.ERROR'));
      } finally {
        this.sending = false;
      }
    },
    onClose() {
      this.$emit('close');
    },
  },
};
</script>

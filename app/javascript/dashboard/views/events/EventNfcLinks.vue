<!--
  Eventos — «Acercar el celular (NFC)»: enlaces de WhatsApp para grabar en etiquetas NFC
  del stand o del gafete de cada vendedor. Quien escribe con el enlace queda en el evento
  como «asistió», con la etiqueta del evento y asignado al vendedor del enlace
  (Events::CaptureMatcher). Grabar desde aquí usa Web NFC (Chrome en Android).
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import EventsAPI from 'dashboard/api/events';
import { copyTextToClipboard } from 'shared/helpers/clipboard';

const T = 'EVENTS.NFC';

export default {
  name: 'EventNfcLinks',
  props: {
    eventId: { type: Number, required: true },
    canEdit: { type: Boolean, default: false },
  },
  data() {
    return {
      links: [],
      inboxes: [],
      defaultMessage: '',
      showForm: false,
      form: { inbox_id: '', user_id: '', message: '' },
      saving: false,
      writingId: null,
    };
  },
  computed: {
    ...mapGetters({ agents: 'agents/getAgents' }),
    webNfc() {
      return typeof window !== 'undefined' && 'NDEFReader' in window;
    },
    label() {
      return this.links[0]?.label || '';
    },
  },
  mounted() {
    this.$store.dispatch('agents/get');
    this.load();
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    async load() {
      const { data } = await EventsAPI.captureLinks(this.eventId);
      this.links = data.links;
      this.inboxes = data.inboxes;
      this.defaultMessage = data.default_message;
    },
    openForm() {
      this.form = {
        inbox_id: this.inboxes[0]?.id || '',
        user_id: '',
        message: this.defaultMessage,
      };
      this.showForm = true;
    },
    async create() {
      this.saving = true;
      try {
        const { data } = await EventsAPI.createCaptureLink(
          this.eventId,
          this.form
        );
        this.links.push(data.link);
        this.showForm = false;
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('ERROR'));
      } finally {
        this.saving = false;
      }
    },
    async remove(link) {
      // eslint-disable-next-line no-alert
      if (!window.confirm(this.t('DELETE_CONFIRM'))) return;
      await EventsAPI.removeCaptureLink(this.eventId, link.id);
      this.links = this.links.filter(l => l.id !== link.id);
    },
    async copy(link) {
      await copyTextToClipboard(link.url);
      useAlert(this.t('COPIED'));
    },
    // Web NFC: el permiso y la escritura se piden al tocar el botón.
    async write(link) {
      if (!this.webNfc) {
        useAlert(this.t('NO_WEB_NFC'));
        return;
      }
      this.writingId = link.id;
      try {
        // eslint-disable-next-line no-undef
        const ndef = new NDEFReader();
        await ndef.write({ records: [{ recordType: 'url', data: link.url }] });
        useAlert(this.t('WRITTEN'));
      } catch (_e) {
        useAlert(this.t('WRITE_ERROR'));
      } finally {
        this.writingId = null;
      }
    },
  },
};
</script>

<template>
  <section class="px-6 py-3 border-t border-slate-50 dark:border-slate-800">
    <div class="flex items-center justify-between gap-2 mb-2">
      <h3
        class="m-0 text-xs font-semibold tracking-wide uppercase text-slate-500 dark:text-slate-400"
      >
        {{ t('TITLE') }}
      </h3>
      <woot-button
        v-if="canEdit && !showForm && inboxes.length"
        size="small"
        variant="smooth"
        icon="add"
        @click="openForm"
      >
        {{ t('NEW') }}
      </woot-button>
    </div>
    <p class="mt-0 mb-3 text-xs text-slate-500">
      {{ t('HELP', { label: label ? `«${label}»` : '' }) }}
    </p>

    <p v-if="!inboxes.length" class="m-0 text-sm text-amber-700">
      {{ t('NO_INBOX') }}
    </p>

    <!-- Nuevo enlace -->
    <div
      v-if="showForm"
      class="grid gap-3 p-3 mb-3 border rounded-lg sm:grid-cols-2 border-slate-100 dark:border-slate-700"
    >
      <label class="text-xs">
        {{ t('INBOX') }}
        <select v-model="form.inbox_id" class="!mb-0 text-sm">
          <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
            {{ inbox.name }} · {{ inbox.phone }}
          </option>
        </select>
      </label>
      <label class="text-xs">
        {{ t('SELLER') }}
        <select v-model="form.user_id" class="!mb-0 text-sm">
          <option value="">{{ t('NO_SELLER') }}</option>
          <option v-for="agent in agents" :key="agent.id" :value="agent.id">
            {{ agent.name }}
          </option>
        </select>
      </label>
      <label class="text-xs sm:col-span-2">
        {{ t('MESSAGE') }}
        <textarea v-model="form.message" rows="2" class="!mb-0 text-sm" />
        <span class="text-slate-500">{{ t('MESSAGE_HINT') }}</span>
      </label>
      <div class="flex justify-end gap-2 sm:col-span-2">
        <woot-button
          size="small"
          variant="clear"
          color-scheme="secondary"
          @click="showForm = false"
        >
          {{ t('CANCEL') }}
        </woot-button>
        <woot-button
          size="small"
          :is-loading="saving"
          :is-disabled="!form.inbox_id || !form.message.trim()"
          @click="create"
        >
          {{ t('CREATE') }}
        </woot-button>
      </div>
    </div>

    <p
      v-if="!links.length && inboxes.length"
      class="m-0 text-sm text-slate-500"
    >
      {{ t('EMPTY') }}
    </p>
    <ul class="flex flex-col gap-2 p-0 m-0 list-none">
      <li
        v-for="link in links"
        :key="link.id"
        class="p-3 border rounded-lg border-slate-100 dark:border-slate-700"
      >
        <div class="flex flex-wrap items-center gap-2 text-sm">
          <span class="font-medium text-slate-800 dark:text-slate-100">
            {{ link.user ? link.user.name : link.inbox.name }}
          </span>
          <span v-if="link.user" class="text-xs text-slate-500">
            {{ `· ${link.inbox.name}` }}
          </span>
          <span
            class="px-2 py-0.5 ml-auto text-xs rounded-full bg-violet-50 text-violet-700 dark:bg-violet-900/40 dark:text-violet-200"
          >
            {{ t('CAPTURES', { count: link.captures }) }}
          </span>
        </div>
        <p class="mt-1 mb-2 text-xs break-words text-slate-500">
          {{ `«${link.message}»` }}
        </p>
        <div class="flex flex-wrap gap-2">
          <woot-button
            size="small"
            icon="flash-on"
            :is-loading="writingId === link.id"
            @click="write(link)"
          >
            {{ writingId === link.id ? t('WRITE_HINT') : t('WRITE') }}
          </woot-button>
          <woot-button
            size="small"
            variant="smooth"
            color-scheme="secondary"
            icon="copy"
            @click="copy(link)"
          >
            {{ t('COPY') }}
          </woot-button>
          <a
            :href="link.url"
            target="_blank"
            rel="noopener noreferrer"
            class="inline-flex items-center px-3 text-xs rounded-md text-woot-600 hover:underline"
          >
            {{ t('TRY') }}
          </a>
          <woot-button
            v-if="canEdit"
            size="small"
            variant="clear"
            color-scheme="alert"
            icon="delete"
            @click="remove(link)"
          >
            {{ t('DELETE') }}
          </woot-button>
        </div>
      </li>
    </ul>
  </section>
</template>

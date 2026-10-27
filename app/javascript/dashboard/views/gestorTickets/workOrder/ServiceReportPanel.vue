<!--
  Plan-Trabajo-Campo R1 — pestaña «Reporte de servicio» de la orden de trabajo
  (en campo o en oficina): dónde se atiende, qué falta para terminarla,
  checklist (las tareas de la orden), bitácora con notas y fotos de antes y
  después, horas (Iniciar / Terminar o a mano) y el reporte para el cliente.
  Los datos de la orden y los materiales siguen abajo en WorkOrderPanel.
-->
<script>
import { useAlert } from 'dashboard/composables';
import ServiceReportsAPI from 'dashboard/api/serviceReports';
import CaseTasksAPI from 'dashboard/api/caseTasks';
import FieldVisitsAPI from 'dashboard/api/fieldVisits';
import Spinner from 'shared/components/Spinner.vue';
import FieldPortalCard from './FieldPortalCard.vue';
import { copyTextToClipboard } from 'shared/helpers/clipboard';

export default {
  name: 'ServiceReportPanel',
  components: { Spinner, FieldPortalCard },
  props: {
    ticket: { type: Object, required: true },
  },
  emits: ['updated'],
  data() {
    return {
      report: null,
      loading: true,
      note: '',
      manualMinutes: '',
      manualNote: '',
      busy: false,
    };
  },
  computed: {
    frozen() {
      return !!this.ticket.is_frozen;
    },
    photos() {
      return (this.report?.logs || []).filter(log => log.kind === 'photo');
    },
    otherLogs() {
      return (this.report?.logs || []).filter(log => log.kind !== 'photo');
    },
  },
  watch: {
    'ticket.id': 'fetch',
  },
  mounted() {
    this.fetch();
  },
  methods: {
    async call(request, okMessage) {
      this.busy = true;
      try {
        const { data } = await request();
        this.report = data.service_report;
        if (okMessage) useAlert(okMessage);
        return true;
      } catch (error) {
        useAlert(
          error?.response?.data?.error || this.$t('SERVICE_REPORT.ERROR')
        );
        return false;
      } finally {
        this.busy = false;
      }
    },
    async fetch() {
      this.loading = true;
      await this.call(() => ServiceReportsAPI.fetch(this.ticket.id));
      this.loading = false;
    },
    setOnSite(value) {
      return this.call(() =>
        ServiceReportsAPI.setOnSite(this.ticket.id, value)
      );
    },
    setAsset(event) {
      const value = event.target.value;
      return this.call(() =>
        ServiceReportsAPI.setAsset(this.ticket.id, value ? Number(value) : null)
      );
    },
    async toggleTask(task) {
      const status = task.status === 'done' ? 'pending' : 'done';
      try {
        await CaseTasksAPI.updateTask(this.ticket.id, task.id, { status });
        await this.fetch();
        this.$emit('updated');
      } catch (error) {
        useAlert(
          error?.response?.data?.error || this.$t('SERVICE_REPORT.ERROR')
        );
      }
    },
    async addNote() {
      if (!this.note.trim()) return;
      const ok = await this.call(() =>
        ServiceReportsAPI.addLog(this.ticket.id, {
          kind: 'note',
          content: this.note.trim(),
        })
      );
      if (ok) this.note = '';
    },
    async upload(event, kind, tag) {
      const [file] = event.target.files || [];
      event.target.value = '';
      if (!file) return;
      await this.call(() =>
        ServiceReportsAPI.addLog(this.ticket.id, { kind, tag, file })
      );
    },
    removeLog(log) {
      return this.call(() =>
        ServiceReportsAPI.removeLog(this.ticket.id, log.id)
      );
    },
    async timer(action) {
      await this.call(() => ServiceReportsAPI.timer(this.ticket.id, action));
      this.$emit('updated');
    },
    async addTime() {
      const minutes = Number(this.manualMinutes);
      if (!minutes) return;
      const ok = await this.call(() =>
        ServiceReportsAPI.addTime(this.ticket.id, {
          minutes,
          note: this.manualNote,
        })
      );
      if (ok) {
        this.manualMinutes = '';
        this.manualNote = '';
        this.$emit('updated');
      }
    },
    async removeTime(entry) {
      await this.call(() =>
        ServiceReportsAPI.removeTime(this.ticket.id, entry.id)
      );
      this.$emit('updated');
    },
    deliver() {
      return this.call(
        () => ServiceReportsAPI.deliver(this.ticket.id),
        this.$t('SERVICE_REPORT.SENT_OK')
      );
    },
    // Plan-Trabajo-Campo R2 — el enlace de la visita al WhatsApp del técnico.
    async sendToTechnician() {
      try {
        await FieldVisitsAPI.sendToTechnician(this.ticket.id);
        useAlert(this.$t('FIELD.SENT_TO_TECH'));
      } catch (error) {
        useAlert(
          error?.response?.data?.error || this.$t('SERVICE_REPORT.ERROR')
        );
      }
    },
    async copyLink() {
      await copyTextToClipboard(this.report.public_url);
      useAlert(this.$t('SERVICE_REPORT.COPIED'));
    },
    openLink() {
      window.open(this.report.public_url, '_blank', 'noopener');
    },
    time(value) {
      return value
        ? new Date(value).toLocaleString(undefined, {
            day: '2-digit',
            month: 'short',
            hour: '2-digit',
            minute: '2-digit',
          })
        : '';
    },
    minutes(value) {
      if (!value && value !== 0) return '—';
      const h = Math.floor(value / 60);
      const m = value % 60;
      return h ? `${h} h ${m} min` : `${m} min`;
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <Spinner v-if="loading" />
    <template v-else-if="report">
      <!-- Dónde se atiende + reporte para el cliente -->
      <section
        class="flex flex-wrap items-center justify-between gap-3 p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
      >
        <div class="flex flex-wrap items-center gap-2 text-sm">
          <span class="font-medium text-slate-700 dark:text-slate-200">{{
            $t('SERVICE_REPORT.WHERE')
          }}</span>
          <div
            class="inline-flex p-0.5 rounded-lg bg-slate-100 dark:bg-slate-700"
          >
            <button
              v-for="option in [true, false]"
              :key="String(option)"
              type="button"
              class="px-3 py-1 rounded-md"
              :class="
                report.on_site === option
                  ? 'bg-white text-slate-800 shadow-sm dark:bg-slate-600 dark:text-slate-100'
                  : 'text-slate-500 dark:text-slate-300'
              "
              :disabled="frozen || busy"
              @click="setOnSite(option)"
            >
              {{
                option
                  ? $t('SERVICE_REPORT.ON_SITE')
                  : $t('SERVICE_REPORT.OFFICE')
              }}
            </button>
          </div>
          <span
            v-if="report.on_site_override === null"
            class="text-xs text-slate-500"
            >{{ $t('SERVICE_REPORT.FROM_TYPE') }}</span
          >
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <span class="text-xs text-slate-500 dark:text-slate-400">
            {{
              report.report_sent_at
                ? $t('SERVICE_REPORT.SENT', {
                    date: time(report.report_sent_at),
                  })
                : $t('SERVICE_REPORT.REPORT')
            }}
          </span>
          <woot-button
            v-if="report.on_site && ticket.assignee_id"
            size="small"
            variant="smooth"
            icon="person"
            @click="sendToTechnician"
          >
            {{ $t('FIELD.SEND_TO_TECH') }}
          </woot-button>
          <woot-button
            size="small"
            icon="send"
            :disabled="busy"
            @click="deliver"
          >
            {{ $t('SERVICE_REPORT.SEND') }}
          </woot-button>
          <woot-button
            size="small"
            variant="smooth"
            color-scheme="secondary"
            icon="copy"
            @click="copyLink"
          >
            {{ $t('SERVICE_REPORT.COPY') }}
          </woot-button>
          <woot-button
            size="small"
            variant="smooth"
            color-scheme="secondary"
            icon="open"
            @click="openLink"
          >
            {{ $t('SERVICE_REPORT.OPEN') }}
          </woot-button>
        </div>
      </section>

      <!-- Plan-Trabajo-Campo R4 — equipo del cliente y mantenimiento de origen -->
      <section
        v-if="report.contact_assets.length || report.customer_asset"
        class="flex flex-wrap items-center gap-3 px-4 py-3 text-sm bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
      >
        <span class="font-medium text-slate-700 dark:text-slate-200">{{
          $t('SERVICE_REPORT.ASSET')
        }}</span>
        <select
          class="!mb-0 w-60"
          :value="report.customer_asset ? report.customer_asset.id : ''"
          :disabled="frozen || busy"
          @change="setAsset"
        >
          <option value="">{{ $t('SERVICE_REPORT.NO_ASSET') }}</option>
          <option v-for="a in report.contact_assets" :key="a.id" :value="a.id">
            {{ a.name }}
          </option>
        </select>
        <span v-if="report.customer_asset" class="text-xs text-slate-500">
          {{
            [
              report.customer_asset.brand,
              report.customer_asset.model,
              report.customer_asset.serial,
            ]
              .filter(Boolean)
              .join(' · ')
          }}
        </span>
        <span v-if="report.maintenance_plan" class="text-xs text-woot-600">
          {{
            $t('SERVICE_REPORT.FROM_PLAN', {
              title: report.maintenance_plan.title,
            })
          }}
        </span>
      </section>

      <!-- Plan-Trabajo-Campo R5 — portal del cliente y técnico externo -->
      <FieldPortalCard
        :ticket="ticket"
        :report="report"
        :frozen="frozen"
        @report="value => (report = value)"
      />

      <!-- Qué falta para terminar -->
      <div
        v-if="report.missing.length"
        class="p-3 text-sm border rounded-lg bg-yellow-50 border-yellow-200 text-yellow-900 dark:bg-yellow-900/20 dark:border-yellow-800 dark:text-yellow-200"
      >
        <strong>{{ $t('SERVICE_REPORT.MISSING_TITLE') }}</strong>
        <ul class="pl-5 m-0 mt-1 list-disc">
          <li v-for="key in report.missing" :key="key">
            {{ $t(`SERVICE_REPORT.MISSING.${key}`) }}
          </li>
        </ul>
      </div>

      <div class="grid grid-cols-1 gap-4 xl:grid-cols-2">
        <!-- Checklist -->
        <section
          class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <h3
            class="m-0 mb-2 text-sm font-semibold text-slate-700 dark:text-slate-200"
          >
            {{ $t('SERVICE_REPORT.CHECKLIST') }}
          </h3>
          <p v-if="!report.checklist.length" class="m-0 text-sm text-slate-500">
            {{ $t('SERVICE_REPORT.CHECKLIST_EMPTY') }}
          </p>
          <label
            v-for="task in report.checklist"
            :key="task.id"
            class="flex items-start gap-2 py-1 mb-0 text-sm"
          >
            <input
              type="checkbox"
              class="mt-1"
              :checked="task.status === 'done'"
              :disabled="frozen"
              @change="toggleTask(task)"
            />
            <span
              :class="{ 'line-through text-slate-500': task.status === 'done' }"
              >{{ task.title }}</span
            >
            <span
              v-if="task.required"
              class="px-1.5 text-[11px] rounded bg-red-50 text-red-700 dark:bg-red-900/30 dark:text-red-300"
              >{{ $t('SERVICE_REPORT.REQUIRED') }}</span
            >
          </label>
        </section>

        <!-- Horas -->
        <section
          class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <div class="flex flex-wrap items-center justify-between gap-2 mb-2">
            <h3
              class="m-0 text-sm font-semibold text-slate-700 dark:text-slate-200"
            >
              {{ $t('SERVICE_REPORT.HOURS') }}
            </h3>
            <span class="text-sm text-slate-600 dark:text-slate-300">{{
              $t('SERVICE_REPORT.TOTAL_HOURS', {
                hours: report.actual_hours || 0,
              })
            }}</span>
          </div>
          <div class="flex flex-wrap items-center gap-2 mb-3">
            <woot-button
              v-if="!report.running_entry"
              size="small"
              color-scheme="success"
              icon="clock"
              :disabled="frozen || busy"
              @click="timer('start')"
            >
              {{ $t('SERVICE_REPORT.START') }}
            </woot-button>
            <template v-else>
              <woot-button
                size="small"
                color-scheme="alert"
                icon="checkmark"
                :disabled="busy"
                @click="timer('stop')"
              >
                {{ $t('SERVICE_REPORT.STOP') }}
              </woot-button>
              <span class="text-xs text-green-700 dark:text-green-300">{{
                $t('SERVICE_REPORT.RUNNING', {
                  time: time(report.running_entry.started_at),
                })
              }}</span>
            </template>
          </div>
          <div
            v-if="!frozen"
            class="grid items-center grid-cols-[6rem_1fr_auto] gap-2 mb-2"
          >
            <input
              v-model="manualMinutes"
              type="number"
              min="1"
              class="!mb-0"
              :placeholder="$t('SERVICE_REPORT.MINUTES')"
            />
            <input
              v-model="manualNote"
              type="text"
              class="!mb-0 flex-1"
              :placeholder="$t('SERVICE_REPORT.NOTE')"
            />
            <woot-button
              size="small"
              variant="smooth"
              :disabled="busy"
              @click="addTime"
            >
              {{ $t('SERVICE_REPORT.ADD_TIME') }}
            </woot-button>
          </div>
          <ul
            class="p-0 m-0 text-sm list-none divide-y divide-slate-50 dark:divide-slate-700"
          >
            <li
              v-for="entry in report.time_entries"
              :key="entry.id"
              class="flex items-center gap-2 py-1"
            >
              <span class="text-slate-500">{{ time(entry.started_at) }}</span>
              <span class="font-medium">{{ minutes(entry.minutes) }}</span>
              <span class="text-xs text-slate-500">{{
                $t(`SERVICE_REPORT.SOURCES.${entry.source}`)
              }}</span>
              <span class="flex-1 truncate text-slate-600 dark:text-slate-300"
                >{{ entry.user && entry.user.name }} {{ entry.note }}</span
              >
              <woot-button
                v-if="entry.mine && !frozen"
                size="tiny"
                variant="clear"
                color-scheme="secondary"
                icon="dismiss"
                @click="removeTime(entry)"
              />
            </li>
          </ul>
        </section>
      </div>

      <!-- Bitácora -->
      <section
        class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
      >
        <h3
          class="m-0 mb-2 text-sm font-semibold text-slate-700 dark:text-slate-200"
        >
          {{ $t('SERVICE_REPORT.LOG') }}
        </h3>
        <div v-if="!frozen" class="flex flex-col gap-2 mb-3">
          <textarea
            v-model="note"
            rows="3"
            class="!mb-0"
            :placeholder="$t('SERVICE_REPORT.LOG_PLACEHOLDER')"
          />
          <div class="flex flex-wrap items-center gap-2">
            <woot-button
              size="small"
              :disabled="busy || !note.trim()"
              @click="addNote"
            >
              {{ $t('SERVICE_REPORT.ADD_NOTE') }}
            </woot-button>
            <label class="mb-0 cursor-pointer button smooth secondary small">
              {{ $t('SERVICE_REPORT.PHOTO_BEFORE') }}
              <input
                type="file"
                accept="image/*"
                capture="environment"
                class="hidden"
                @change="upload($event, 'photo', 'before')"
              />
            </label>
            <label class="mb-0 cursor-pointer button smooth secondary small">
              {{ $t('SERVICE_REPORT.PHOTO_AFTER') }}
              <input
                type="file"
                accept="image/*"
                capture="environment"
                class="hidden"
                @change="upload($event, 'photo', 'after')"
              />
            </label>
            <label class="mb-0 cursor-pointer button smooth secondary small">
              {{ $t('SERVICE_REPORT.ATTACH') }}
              <input
                type="file"
                class="hidden"
                @change="upload($event, 'document', null)"
              />
            </label>
          </div>
        </div>
        <p v-if="!report.logs.length" class="m-0 text-sm text-slate-500">
          {{ $t('SERVICE_REPORT.LOG_EMPTY') }}
        </p>
        <div
          v-if="photos.length"
          class="grid grid-cols-2 gap-3 mb-3 sm:grid-cols-4"
        >
          <figure v-for="log in photos" :key="log.id" class="relative m-0">
            <a :href="log.file_url" target="_blank" rel="noopener noreferrer">
              <img
                :src="log.file_url"
                alt=""
                class="object-cover w-full h-32 rounded-lg"
              />
            </a>
            <figcaption
              class="flex items-center justify-between mt-1 text-xs text-slate-500"
            >
              <span
                >{{ log.tag ? $t(`SERVICE_REPORT.TAGS.${log.tag}`) : '' }} ·
                {{ time(log.created_at) }}</span
              >
              <woot-button
                v-if="log.mine && !frozen"
                size="tiny"
                variant="clear"
                color-scheme="secondary"
                icon="dismiss"
                @click="removeLog(log)"
              />
            </figcaption>
          </figure>
        </div>
        <ul
          class="p-0 m-0 list-none divide-y divide-slate-50 dark:divide-slate-700"
        >
          <li
            v-for="log in otherLogs"
            :key="log.id"
            class="flex items-start gap-2 py-2 text-sm"
          >
            <fluent-icon
              :icon="log.kind === 'note' ? 'document' : 'attach'"
              size="16"
              class="mt-0.5 text-slate-400"
            />
            <div class="flex-1 min-w-0">
              <p
                v-if="log.kind === 'note'"
                class="m-0 text-slate-800 dark:text-slate-100"
              >
                <span class="whitespace-pre-line">{{ log.content }}</span>
              </p>
              <a
                v-else
                :href="log.file_url"
                target="_blank"
                rel="noopener noreferrer"
                class="text-woot-600"
                >{{ log.file_name }}</a
              >
              <span class="block text-xs text-slate-500"
                >{{ log.user && log.user.name }} ·
                {{ time(log.created_at) }}</span
              >
            </div>
            <woot-button
              v-if="log.mine && !frozen"
              size="tiny"
              variant="clear"
              color-scheme="secondary"
              icon="dismiss"
              @click="removeLog(log)"
            />
          </li>
        </ul>
      </section>
    </template>
  </div>
</template>

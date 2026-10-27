<!--
  Plan-Trabajo-Campo R2 — una visita en el celular del técnico, de arriba a
  abajo: datos y accesos (cómo llegar, llamar, WhatsApp), «Voy en camino»,
  «Llegué», checklist, bitácora con fotos de antes y después, materiales del
  catálogo, cotizar trabajo adicional y «Terminé» con la firma del cliente.
  Usa los mismos datos del reporte de servicio que la orden en la computadora.
  R5: sin señal, «Llegué», las notas y «Terminé» se guardan y se mandan al volver
  (offlineQueue.js), con la hora en que pasaron.
-->
<script>
import { useAlert } from 'dashboard/composables';
import FieldVisitsAPI from 'dashboard/api/fieldVisits';
import ServiceReportsAPI from 'dashboard/api/serviceReports';
import CaseTasksAPI from 'dashboard/api/caseTasks';
import CaseTicketsAPI from 'dashboard/api/caseTickets';
import QuotesAPI from 'dashboard/api/quotes';
import CatalogPicker from '../gestorTickets/catalog/CatalogPicker.vue';
import SignaturePad from './SignaturePad.vue';
import { currentLocation, mapsUrl, whatsappUrl } from './location';
import { enqueue, flush, isOffline, pending } from './offlineQueue';

const ETAS = [10, 20, 30, 45, 60];

export default {
  name: 'FieldVisit',
  components: { CatalogPicker, SignaturePad },
  props: {
    ticketId: { type: Number, required: true },
  },
  data() {
    return {
      visit: null,
      loading: true,
      busy: false,
      locating: false,
      eta: 20,
      note: '',
      showFinish: false,
      receivedBy: '',
      conformityNote: '',
      signature: '',
      extraItems: [],
      extraQuote: null,
      // Plan-Trabajo-Campo R5 — sin señal.
      online: navigator.onLine,
      queued: pending(this.ticketId),
    };
  },
  computed: {
    etas() {
      return ETAS;
    },
    report() {
      return this.visit ? this.visit.report : null;
    },
    photos() {
      return (this.report?.logs || []).filter(log => log.kind === 'photo');
    },
    notes() {
      return (this.report?.logs || []).filter(log => log.kind === 'note');
    },
    done() {
      return this.visit && this.visit.state === 'done';
    },
  },
  mounted() {
    this.fetch();
    window.addEventListener('online', this.onOnline);
    window.addEventListener('offline', this.onOffline);
    if (this.online && this.queued.length) this.sync();
  },
  beforeDestroy() {
    window.removeEventListener('online', this.onOnline);
    window.removeEventListener('offline', this.onOffline);
  },
  methods: {
    maps: mapsUrl,
    whatsapp: whatsappUrl,
    fail(error) {
      useAlert(error?.response?.data?.error || this.$t('FIELD.ERROR'));
    },
    async fetch() {
      try {
        const { data } = await FieldVisitsAPI.show(this.ticketId);
        this.visit = data.visit;
        if (!this.receivedBy && this.visit.contact)
          this.receivedBy = this.visit.contact.name;
      } catch (error) {
        this.fail(error);
      } finally {
        this.loading = false;
      }
    },
    // `queue` ({ kind, payload }): si no hay señal se guarda en el celular y se
    // manda después (también si ya hay pendientes, para no saltarse el orden).
    async act(request, okMessage, queue = null) {
      if (queue && this.queued.length) return this.saveOffline(queue);
      this.busy = true;
      try {
        const { data } = await request();
        if (data.visit) this.visit = data.visit;
        if (data.service_report && this.visit)
          this.visit.report = data.service_report;
        if (okMessage) useAlert(okMessage);
        return true;
      } catch (error) {
        if (queue && isOffline(error)) return this.saveOffline(queue);
        this.fail(error);
        return false;
      } finally {
        this.busy = false;
      }
    },
    saveOffline({ kind, payload }) {
      const item = enqueue(this.ticketId, kind, payload);
      this.queued = pending(this.ticketId);
      if (kind === 'arrive') {
        this.visit = {
          ...this.visit,
          state: 'working',
          visit_entry: { started_at: item.payload.occurred_at },
        };
      }
      if (kind === 'finish') this.visit = { ...this.visit, state: 'done' };
      useAlert(this.$t('FIELD.OFFLINE.SAVED'));
      return true;
    },
    onOnline() {
      this.online = true;
      this.sync();
    },
    onOffline() {
      this.online = false;
    },
    async sync() {
      if (!pending(this.ticketId).length) return;
      const { sent, rejected } = await flush();
      this.queued = pending(this.ticketId);
      rejected.forEach(({ message }) =>
        useAlert(message || this.$t('FIELD.ERROR'))
      );
      if (sent) useAlert(this.$t('FIELD.OFFLINE.SYNCED', { n: sent }));
      if (sent || rejected.length) await this.fetch();
    },
    onMyWay() {
      return this.act(
        () => FieldVisitsAPI.onMyWay(this.ticketId, this.eta),
        this.$t('FIELD.ON_MY_WAY_SENT')
      );
    },
    async arrive() {
      this.locating = true;
      const location = await currentLocation();
      this.locating = false;
      await this.act(
        () => FieldVisitsAPI.arrive(this.ticketId, location),
        null,
        { kind: 'arrive', payload: location }
      );
    },
    async toggleTask(task) {
      try {
        await CaseTasksAPI.updateTask(this.ticketId, task.id, {
          status: task.status === 'done' ? 'pending' : 'done',
        });
        await this.fetch();
      } catch (error) {
        this.fail(error);
      }
    },
    async addNote() {
      if (!this.note.trim()) return;
      const content = this.note.trim();
      const ok = await this.act(
        () =>
          ServiceReportsAPI.addLog(this.ticketId, { kind: 'note', content }),
        null,
        { kind: 'note', payload: { content } }
      );
      if (ok) this.note = '';
    },
    async photo(event, tag) {
      const [file] = event.target.files || [];
      event.target.value = '';
      if (!file) return;
      await this.act(() =>
        ServiceReportsAPI.addLog(this.ticketId, { kind: 'photo', tag, file })
      );
    },
    async addMaterial(item) {
      try {
        await CaseTicketsAPI.createWorkOrderItem(this.ticketId, {
          description: item.name,
          quantity: 1,
          unit: item.unit,
          unit_cost: item.price,
          catalog_item_id: item.id,
        });
        await this.fetch();
      } catch (error) {
        this.fail(error);
      }
    },
    addExtra(item) {
      this.extraItems.push({ ...item, quantity: 1 });
    },
    async createExtraQuote() {
      if (!this.extraItems.length) {
        useAlert(this.$t('FIELD.EXTRA_EMPTY'));
        return;
      }
      try {
        const { data } = await QuotesAPI.createQuote({
          quote: {
            contact_id: this.visit.contact.id,
            origin_ticket_id: this.ticketId,
          },
          items: this.extraItems.map(item => ({
            catalog_item_id: item.id,
            description: item.name,
            kind: item.kind,
            unit: item.unit,
            quantity: item.quantity,
            unit_price: item.price,
          })),
        });
        this.extraQuote = data.quote;
        this.extraItems = [];
        useAlert(this.$t('FIELD.EXTRA_DONE', { folio: data.quote.folio }));
      } catch (error) {
        this.fail(error);
      }
    },
    async sendExtraQuote() {
      try {
        const { data } = await QuotesAPI.deliver(this.extraQuote.id);
        this.extraQuote = data.quote;
        useAlert(this.$t('FIELD.EXTRA_SENT'));
      } catch (error) {
        this.fail(error);
      }
    },
    async finish() {
      this.locating = true;
      const location = await currentLocation();
      this.locating = false;
      const payload = {
        ...location,
        received_by: this.receivedBy,
        conformity_note: this.conformityNote,
        signature: this.signature,
      };
      const ok = await this.act(
        () => FieldVisitsAPI.finish(this.ticketId, payload),
        this.$t('FIELD.FINISHED'),
        { kind: 'finish', payload }
      );
      if (ok) this.showFinish = false;
    },
    hour(value) {
      return value
        ? new Date(value).toLocaleTimeString(undefined, {
            hour: '2-digit',
            minute: '2-digit',
          })
        : '';
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <p v-if="loading" class="py-8 text-center text-slate-500">
      {{ $t('FIELD.LOADING') }}
    </p>
    <template v-else-if="visit">
      <!-- Plan-Trabajo-Campo R5 — sin señal: lo guardado se manda al volver -->
      <section
        v-if="!online || queued.length"
        class="p-3 text-sm text-yellow-900 border border-yellow-200 rounded-xl bg-yellow-50"
      >
        <p class="m-0 font-semibold">
          {{ online ? $t('FIELD.OFFLINE.PENDING') : $t('FIELD.OFFLINE.TITLE') }}
        </p>
        <p class="m-0">
          {{ $t('FIELD.OFFLINE.HELP', { n: queued.length }) }}
        </p>
        <ul v-if="queued.length" class="pl-5 m-0 mt-1 list-disc">
          <li v-for="item in queued" :key="item.id">
            {{ $t(`FIELD.OFFLINE.KINDS.${item.kind}`) }}
            <span v-if="item.kind === 'note'" class="text-yellow-800">
              · {{ item.payload.content }}
            </span>
          </li>
        </ul>
        <button
          v-if="online && queued.length"
          type="button"
          class="mt-2 font-semibold underline"
          @click="sync"
        >
          {{ $t('FIELD.OFFLINE.RETRY') }}
        </button>
      </section>
      <!-- Datos y accesos -->
      <section class="p-4 bg-white shadow-sm rounded-xl">
        <p class="m-0 text-xs font-semibold text-woot-600">
          {{ visit.folio }} · {{ $t(`FIELD.STATES.${visit.state}`) }}
        </p>
        <h1 class="m-0 text-lg font-bold text-slate-800">{{ visit.title }}</h1>
        <p class="m-0 text-base text-slate-700">
          {{ visit.contact && visit.contact.name }}
        </p>
        <p v-if="visit.work_address" class="m-0 mt-1 text-sm text-slate-500">
          {{ visit.work_address }}
        </p>
        <p v-if="visit.description" class="m-0 mt-2 text-sm text-slate-600">
          <span class="whitespace-pre-line">{{ visit.description }}</span>
        </p>
        <div class="flex gap-2 mt-3">
          <a
            v-if="visit.work_address"
            :href="maps(visit.work_address)"
            target="_blank"
            rel="noopener noreferrer"
            class="flex-1 py-2 text-sm font-medium text-center rounded-lg bg-slate-100 text-slate-700"
          >
            {{ $t('FIELD.DIRECTIONS') }}
          </a>
          <a
            v-if="visit.contact && visit.contact.phone_number"
            :href="`tel:${visit.contact.phone_number}`"
            class="flex-1 py-2 text-sm font-medium text-center rounded-lg bg-slate-100 text-slate-700"
          >
            {{ $t('FIELD.CALL') }}
          </a>
          <a
            v-if="visit.contact && visit.contact.phone_number"
            :href="whatsapp(visit.contact.phone_number)"
            target="_blank"
            rel="noopener noreferrer"
            class="flex-1 py-2 text-sm font-medium text-center text-green-800 bg-green-100 rounded-lg"
          >
            {{ $t('FIELD.WHATSAPP') }}
          </a>
        </div>
      </section>

      <!-- Voy en camino / Llegué -->
      <section
        v-if="visit.state === 'pending' || visit.state === 'on_the_way'"
        class="flex flex-col gap-3 p-4 bg-white shadow-sm rounded-xl"
      >
        <div class="flex items-center gap-2">
          <span class="text-sm text-slate-600">{{ $t('FIELD.ETA') }}</span>
          <select v-model="eta" class="!mb-0 flex-1">
            <option v-for="n in etas" :key="n" :value="n">
              {{ $t('FIELD.MINUTES', { n }) }}
            </option>
          </select>
          <woot-button variant="smooth" :disabled="busy" @click="onMyWay">
            {{ $t('FIELD.ON_MY_WAY') }}
          </woot-button>
        </div>
        <button
          type="button"
          class="w-full py-4 text-lg font-bold text-white rounded-xl bg-woot-500 disabled:opacity-60"
          :disabled="busy || locating"
          @click="arrive"
        >
          {{ locating ? $t('FIELD.LOCATING') : $t('FIELD.ARRIVE') }}
        </button>
      </section>
      <p
        v-else-if="visit.visit_entry"
        class="m-0 text-sm text-center text-slate-500"
      >
        {{ $t('FIELD.ARRIVED', { time: hour(visit.visit_entry.started_at) }) }}
      </p>

      <!-- Checklist -->
      <section
        v-if="report && report.checklist.length"
        class="p-4 bg-white shadow-sm rounded-xl"
      >
        <h2 class="m-0 mb-2 text-sm font-semibold text-slate-700">
          {{ $t('FIELD.CHECKLIST') }}
        </h2>
        <label
          v-for="task in report.checklist"
          :key="task.id"
          class="flex items-center gap-3 py-2 mb-0 text-base"
        >
          <input
            type="checkbox"
            class="w-5 h-5 m-0"
            :checked="task.status === 'done'"
            :disabled="done"
            @change="toggleTask(task)"
          />
          <span
            :class="{ 'line-through text-slate-400': task.status === 'done' }"
            >{{ task.title }}</span
          >
        </label>
      </section>

      <!-- Bitácora -->
      <section
        v-if="report"
        class="flex flex-col gap-2 p-4 bg-white shadow-sm rounded-xl"
      >
        <h2 class="m-0 text-sm font-semibold text-slate-700">
          {{ $t('FIELD.LOG') }}
        </h2>
        <div v-if="!done" class="grid grid-cols-2 gap-2">
          <label
            class="py-3 mb-0 text-sm font-medium text-center rounded-lg cursor-pointer bg-slate-100 text-slate-700"
          >
            {{ $t('FIELD.PHOTO_BEFORE') }}
            <input
              type="file"
              accept="image/*"
              capture="environment"
              class="hidden"
              @change="photo($event, 'before')"
            />
          </label>
          <label
            class="py-3 mb-0 text-sm font-medium text-center rounded-lg cursor-pointer bg-slate-100 text-slate-700"
          >
            {{ $t('FIELD.PHOTO_AFTER') }}
            <input
              type="file"
              accept="image/*"
              capture="environment"
              class="hidden"
              @change="photo($event, 'after')"
            />
          </label>
        </div>
        <div v-if="photos.length" class="grid grid-cols-3 gap-2">
          <img
            v-for="log in photos"
            :key="log.id"
            :src="log.file_url"
            alt=""
            class="object-cover w-full h-24 rounded-lg"
          />
        </div>
        <template v-if="!done">
          <textarea
            v-model="note"
            rows="3"
            class="!mb-0"
            :placeholder="$t('FIELD.NOTE_PLACEHOLDER')"
          />
          <woot-button
            variant="smooth"
            :disabled="busy || !note.trim()"
            @click="addNote"
          >
            {{ $t('FIELD.ADD_NOTE') }}
          </woot-button>
        </template>
        <p
          v-for="log in notes"
          :key="log.id"
          class="p-2 m-0 text-sm rounded-lg bg-slate-50 text-slate-700"
        >
          <span class="whitespace-pre-line">{{ log.content }}</span>
        </p>
      </section>

      <!-- Materiales -->
      <section class="flex flex-col gap-2 p-4 bg-white shadow-sm rounded-xl">
        <h2 class="m-0 text-sm font-semibold text-slate-700">
          {{ $t('FIELD.MATERIALS') }}
        </h2>
        <CatalogPicker
          v-if="!done"
          :allow-free="false"
          :placeholder="$t('FIELD.ADD_MATERIAL')"
          @select="addMaterial"
        />
        <ul class="p-0 m-0 text-sm list-none divide-y divide-slate-100">
          <li
            v-for="item in visit.items"
            :key="item.id"
            class="flex justify-between py-1"
          >
            <span>{{ item.description }}</span>
            <span class="text-slate-500"
              >{{ item.quantity }} {{ item.unit }}</span
            >
          </li>
        </ul>
      </section>

      <!-- Cotizar trabajo adicional -->
      <section
        v-if="visit.contact"
        class="flex flex-col gap-2 p-4 bg-white shadow-sm rounded-xl"
      >
        <h2 class="m-0 text-sm font-semibold text-slate-700">
          {{ $t('FIELD.EXTRA') }}
        </h2>
        <CatalogPicker :allow-free="false" @select="addExtra" />
        <div
          v-for="(item, index) in extraItems"
          :key="index"
          class="flex items-center gap-2 text-sm"
        >
          <span class="flex-1">{{ item.name }}</span>
          <input
            v-model="item.quantity"
            type="number"
            min="1"
            class="!mb-0 w-20"
            :aria-label="$t('FIELD.QTY')"
          />
        </div>
        <woot-button
          v-if="extraItems.length"
          variant="smooth"
          @click="createExtraQuote"
        >
          {{ $t('FIELD.EXTRA_CREATE') }}
        </woot-button>
        <div v-if="extraQuote" class="flex flex-col gap-2">
          <p class="m-0 text-sm text-green-800">
            {{ $t('FIELD.EXTRA_DONE', { folio: extraQuote.folio }) }}
          </p>
          <a
            :href="extraQuote.public_url"
            target="_blank"
            rel="noopener noreferrer"
            class="py-2 text-sm font-medium text-center text-white rounded-lg bg-woot-500"
          >
            {{ $t('FIELD.EXTRA_ACCEPT_HERE') }}
          </a>
          <woot-button variant="smooth" @click="sendExtraQuote">
            {{ $t('FIELD.EXTRA_SEND') }}
          </woot-button>
        </div>
      </section>

      <!-- Qué falta -->
      <div
        v-if="report && report.missing.length && !done"
        class="p-3 text-sm text-yellow-900 bg-yellow-100 rounded-xl"
      >
        <strong>{{ $t('FIELD.MISSING') }}</strong>
        <ul class="pl-5 m-0 mt-1 list-disc">
          <li v-for="key in report.missing" :key="key">
            {{ $t(`SERVICE_REPORT.MISSING.${key}`) }}
          </li>
        </ul>
      </div>

      <!-- Terminé -->
      <template v-if="!done">
        <button
          v-if="!showFinish"
          type="button"
          class="w-full py-4 text-lg font-bold text-white bg-green-600 rounded-xl"
          @click="showFinish = true"
        >
          {{ $t('FIELD.FINISH') }}
        </button>
        <section
          v-else
          class="flex flex-col gap-2 p-4 bg-white shadow-sm rounded-xl"
        >
          <h2 class="m-0 text-sm font-semibold text-slate-700">
            {{ $t('FIELD.FINISH_TITLE') }}
          </h2>
          <label class="mb-0 text-sm">
            {{ $t('FIELD.RECEIVED_BY') }}
            <input v-model="receivedBy" type="text" class="!mb-0" />
          </label>
          <label class="mb-0 text-sm">
            {{ $t('FIELD.NOTE') }}
            <textarea v-model="conformityNote" rows="2" class="!mb-0" />
          </label>
          <span class="text-sm">{{ $t('FIELD.SIGN') }}</span>
          <SignaturePad v-model="signature" />
          <button
            type="button"
            class="w-full py-4 text-lg font-bold text-white bg-green-600 rounded-xl disabled:opacity-60"
            :disabled="busy || locating"
            @click="finish"
          >
            {{ locating ? $t('FIELD.LOCATING') : $t('FIELD.CONFIRM_FINISH') }}
          </button>
        </section>
      </template>
    </template>
  </div>
</template>

<!--
  Visitas — la visita de una tarea agendada (el vendedor), en el celular: cómo llegar,
  llamar, Voy en camino, Llegué con su ubicación y Concluir con el reporte de cierre.
-->
<script>
import { useAlert } from 'dashboard/composables';
import AgendaItemsAPI from 'dashboard/api/agendaItems';
import AgendaVisitsAPI from 'dashboard/api/agendaVisits';
import TaskReportModal from 'dashboard/views/gestorTickets/tasks/TaskReportModal.vue';
import taskReportFlow from 'dashboard/mixins/taskReportFlow';
import { currentLocation, mapsUrl, whatsappUrl } from './location';

const ETAS = [10, 20, 30, 45, 60];

export default {
  name: 'FieldAgendaVisit',
  components: { TaskReportModal },
  mixins: [taskReportFlow],
  props: {
    meetingId: { type: Number, required: true },
  },
  data() {
    return { visit: null, eta: 20, busy: false, etas: ETAS };
  },
  computed: {
    arrivedLabel() {
      return new Date(this.visit.arrived_at).toLocaleTimeString(undefined, {
        hour: '2-digit',
        minute: '2-digit',
      });
    },
    hasLocation() {
      return this.visit.arrival_location?.lat !== undefined;
    },
  },
  mounted() {
    this.fetch();
  },
  methods: {
    async run(request) {
      this.busy = true;
      try {
        const { data } = await request();
        if (data?.visit) this.visit = data.visit;
      } catch (error) {
        useAlert(error?.response?.data?.error || this.$t('FIELD.ERROR'));
      } finally {
        this.busy = false;
      }
    },
    fetch() {
      return this.run(() => AgendaVisitsAPI.show(this.meetingId));
    },
    onMyWay() {
      this.run(() => AgendaVisitsAPI.onMyWay(this.meetingId, this.eta));
    },
    async arrive() {
      this.busy = true;
      const location = await currentLocation();
      if (location.lat === undefined) {
        useAlert(this.$t('FIELD.NO_LOCATION'));
      }
      this.run(() => AgendaVisitsAPI.arrive(this.meetingId, location));
    },
    conclude() {
      const { title } = this.visit;
      this.askReport({ type: 'meeting', id: this.meetingId, title }, () =>
        this.finish()
      );
    },
    async finish() {
      await this.run(() =>
        AgendaItemsAPI.updateItem(this.meetingId, { status: 'held' })
      );
      this.fetch();
    },
    maps: mapsUrl,
    whatsapp: whatsappUrl,
  },
};
</script>

<template>
  <div v-if="visit" class="flex flex-col gap-3">
    <section class="p-4 bg-white shadow-sm rounded-xl">
      <p class="m-0 text-lg font-semibold text-slate-800">
        {{ visit.contact ? visit.contact.name : visit.organization }}
      </p>
      <p class="m-0 text-sm text-slate-600">
        <template v-if="visit.folio">{{ visit.folio }} · </template>
        {{ visit.title }}
      </p>
      <p v-if="visit.work_address" class="m-0 mt-1 text-sm text-slate-500">
        {{ visit.work_address }}
      </p>
      <p v-if="visit.description" class="mt-2 mb-0 text-sm text-slate-600">
        {{ visit.description }}
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
        <template v-if="visit.contact && visit.contact.phone_number">
          <a
            :href="`tel:${visit.contact.phone_number}`"
            class="flex-1 py-2 text-sm font-medium text-center rounded-lg bg-slate-100 text-slate-700"
          >
            {{ $t('FIELD.CALL') }}
          </a>
          <a
            :href="whatsapp(visit.contact.phone_number)"
            target="_blank"
            rel="noopener noreferrer"
            class="flex-1 py-2 text-sm font-medium text-center text-green-800 bg-green-100 rounded-lg"
          >
            {{ $t('FIELD.WHATSAPP') }}
          </a>
        </template>
      </div>
    </section>

    <section class="flex flex-col gap-2 p-4 bg-white shadow-sm rounded-xl">
      <p class="m-0 text-sm font-medium text-slate-700">
        {{ $t(`FIELD.STATES.${visit.state}`) }}
      </p>
      <div v-if="visit.state === 'pending'" class="flex items-center gap-2">
        <select v-model="eta" class="!mb-0 flex-1">
          <option v-for="n in etas" :key="n" :value="n">
            {{ $t('FIELD.ETA_OPTION', { n }) }}
          </option>
        </select>
        <woot-button variant="smooth" :disabled="busy" @click="onMyWay">
          {{ $t('FIELD.ON_MY_WAY') }}
        </woot-button>
      </div>
      <woot-button
        v-if="!visit.arrived_at && visit.state !== 'done'"
        :is-loading="busy"
        @click="arrive"
      >
        {{ $t('FIELD.ARRIVE') }}
      </woot-button>
      <p v-if="visit.arrived_at" class="m-0 text-sm text-slate-600">
        {{ $t('FIELD.ARRIVED', { time: arrivedLabel }) }}
        <template v-if="!hasLocation">
          · {{ $t('FIELD.NO_LOCATION') }}
        </template>
      </p>
      <woot-button
        v-if="visit.state !== 'done'"
        variant="smooth"
        :disabled="busy"
        @click="conclude"
      >
        {{ $t('TASK_REPORT.SUBMIT') }}
      </woot-button>
    </section>
    <TaskReportModal
      :item="reportItem"
      @close="cancelReport"
      @reported="onReported"
    />
  </div>
</template>

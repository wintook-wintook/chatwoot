<script>
// proyecto@asistente_agentes_ia — «PROBAR EL AGENTE» (M5 de docs/importar_prompt_extenso_plan.md)
// ============================================================================
// La pila de pruebas en vivo del agente GUARDADO: una conversación por prueba en el
// canal de pruebas de la cuenta (API sin webhook: ahí nada le llega a un cliente),
// con el motor real, calificada contra la «Verificación» de cada regla y el estilo
// del agente.
//
// A diferencia del banco de pruebas (DryRunModal), esto SÍ es el agente
// contestando. Por eso cuesta y se corre con botón (decisión D4), y el agente
// tiene que estar guardado: se prueba lo que van a recibir los clientes.
// ============================================================================
import AssistantAPI from 'dashboard/api/assistant';
// proyecto@diagrama_agente_ia F2: arrancar y seguir la pila lo comparte con el panel Pruebas.
import testBatteryRunner from './testBatteryRunner';

export default {
  mixins: [testBatteryRunner],
  props: {
    show: { type: Boolean, default: false },
    templateId: { type: Number, default: null },
    templateName: { type: String, default: '' },
    // El encargo del que salió el agente, si lo hay: de ahí salen las reglas a probar.
    briefId: { type: Number, default: null },
  },
  emits: ['close'],
  computed: {
    batteryTemplateId() {
      return this.templateId;
    },
    batteryBriefId() {
      return this.briefId;
    },
  },
  methods: {
    async download() {
      const { data } = await AssistantAPI.downloadTestBatteryReport(
        this.batteryId
      );
      const enlace = document.createElement('a');
      enlace.href = URL.createObjectURL(data);
      enlace.download = `pila_${this.templateId}.md`;
      enlace.click();
      URL.revokeObjectURL(enlace.href);
    },
    routeMark(resultado) {
      if (resultado.ruta_ok === true) return '✅';
      if (resultado.ruta_ok === false) return '❌';
      return '—';
    },
    close() {
      this.stop();
      this.$emit('close');
    },
  },
};
</script>

<template>
  <woot-modal :show="show" size="dry-run-wide" :on-close="close">
    <div class="flex flex-col p-8 h-[80vh]">
      <h2
        class="mb-1 text-base font-semibold leading-6 text-slate-800 dark:text-slate-50"
      >
        {{
          $t('TRACKING_ASSISTANT_VIEW.BATTERY_TITLE', { name: templateName })
        }}
      </h2>
      <p class="mb-4 text-xs shrink-0 text-slate-500 dark:text-slate-400">
        {{ $t('TRACKING_ASSISTANT_VIEW.BATTERY_HINT') }}
      </p>

      <div class="flex flex-wrap items-center gap-3 mb-4 shrink-0">
        <woot-button
          size="small"
          icon="play-circle"
          :is-loading="running"
          :is-disabled="running || !templateId"
          @click="start()"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.BATTERY_RUN') }}
        </woot-button>
        <span v-if="running" class="text-xs text-slate-500">{{
          progress
        }}</span>
        <span
          v-if="stateStatus === 'done'"
          class="text-xs font-medium text-slate-700 dark:text-slate-200"
        >
          {{
            $t('TRACKING_ASSISTANT_VIEW.BATTERY_SUMMARY', {
              passed,
              total: results.length,
            })
          }}
        </span>
        <woot-button
          v-if="stateStatus === 'done'"
          size="small"
          variant="smooth"
          icon="arrow-download"
          @click="download"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.BATTERY_DOWNLOAD') }}
        </woot-button>
      </div>

      <p
        v-if="error"
        class="p-3 mb-4 text-xs rounded-lg bg-amber-50 dark:bg-amber-900/20 text-amber-900 dark:text-amber-800"
      >
        {{ error }}
      </p>

      <div class="flex-1 min-h-0 overflow-y-auto">
        <table v-if="results.length" class="w-full text-xs">
          <thead>
            <tr class="text-left text-slate-500">
              <th class="py-1 pr-2">
                {{ $t('TRACKING_ASSISTANT_VIEW.BATTERY_COL_TEST') }}
              </th>
              <th class="py-1 pr-2">
                {{ $t('TRACKING_ASSISTANT_VIEW.BATTERY_COL_CUSTOMER') }}
              </th>
              <th class="py-1 pr-2">
                {{ $t('TRACKING_ASSISTANT_VIEW.BATTERY_COL_AGENT') }}
              </th>
              <th class="py-1 pr-2">
                {{ $t('TRACKING_ASSISTANT_VIEW.BATTERY_COL_ROUTE') }}
              </th>
              <th class="py-1 pr-2">
                {{ $t('TRACKING_ASSISTANT_VIEW.BATTERY_COL_OK') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="resultado in results"
              :key="resultado.id"
              class="align-top border-t border-slate-100 dark:border-slate-700"
            >
              <td class="py-2 pr-2 text-slate-600 dark:text-slate-300">
                {{ resultado.id }}
                <span class="block text-slate-400">
                  #{{ resultado.conversation }}
                </span>
              </td>
              <td class="py-2 pr-2 text-slate-800 dark:text-slate-100">
                {{ resultado.message }}
              </td>
              <td
                class="py-2 pr-2 whitespace-pre-line text-slate-800 dark:text-slate-100"
              >
                {{ resultado.reply }}
              </td>
              <td class="py-2 pr-2">{{ routeMark(resultado) }}</td>
              <td class="py-2 pr-2">
                {{ resultado.cumple ? '✅' : '❌' }}
                <span class="block text-slate-500">{{ resultado.motivo }}</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </woot-modal>
</template>

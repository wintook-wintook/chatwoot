<script>
// diag/llamadas_whatsapp (F6) — PESTAÑA «LLAMADAS» DE UNA BANDEJA DE WHATSAPP CLOUD
// ============================================================================
// Activar · tipo (ambas / solo entrantes / solo salientes) · a quién le suena
// (cascada / todos en línea) · texto con que se pide permiso al cliente.
// Prender o cambiar el tipo habla con Meta (o la Meta simulada); si Meta lo rechaza,
// se muestra su mensaje. Grabación (F7): interruptor y el aviso que recibe el cliente.
// Llamada perdida (F8): qué hacer cuando nadie contesta (Calls::MissedCallService).
// ============================================================================
import { useAlert } from 'dashboard/composables';
import SettingsSection from 'dashboard/components/SettingsSection.vue';
import WhatsappCallSettingsAPI from 'dashboard/api/whatsappCallSettings';

const MISSED_ACTIONS = ['note', 'label', 'ticket', 'tracking', 'auto_reply'];
const MISSED_FIELDS = [
  'missed_call_actions',
  'missed_call_label',
  'missed_call_case_type_id',
  'missed_call_campaign_id',
  'missed_call_auto_reply',
];

export default {
  components: { SettingsSection },
  props: {
    inbox: { type: Object, required: true },
  },
  data() {
    return {
      isLoading: true,
      isSaving: false,
      settings: null,
      form: {
        enabled: false,
        direction: 'both',
        ring_strategy: 'cascade',
        call_permission_request_body: '',
        recording_enabled: false,
        recording_notice: '',
        missed_call_actions: [],
        missed_call_label: '',
        missed_call_case_type_id: null,
        missed_call_campaign_id: null,
        missed_call_auto_reply: '',
      },
      missedActions: MISSED_ACTIONS,
    };
  },
  computed: {
    metaStatus() {
      const estado = this.settings && this.settings.meta_status;
      return estado && estado.status ? estado.status : '';
    },
    simulatorRoute() {
      return {
        name: 'whatsapp_call_simulator',
        params: { accountId: this.$route.params.accountId },
      };
    },
    missedOptions() {
      const opciones = this.settings && this.settings.missed_call_options;
      return opciones || { labels: [], case_types: [], campaigns: [] };
    },
    acceptsInbound() {
      return this.form.enabled && this.form.direction !== 'outbound';
    },
    needsManualWebhook() {
      return Boolean(
        this.settings &&
          this.settings.enabled &&
          this.settings.calls_webhook === 'manual'
      );
    },
  },
  mounted() {
    this.load();
  },
  methods: {
    t(key, args) {
      return this.$t(`WHATSAPP_CALLS.SETTINGS.${key}`, args);
    },
    fill(data) {
      this.settings = data;
      this.form = {
        enabled: data.enabled,
        direction: data.direction,
        ring_strategy: data.ring_strategy,
        call_permission_request_body: data.call_permission_request_body,
        recording_enabled: data.recording_enabled,
        recording_notice: data.recording_notice,
      };
      MISSED_FIELDS.forEach(campo => {
        this.form[campo] = data[campo];
      });
      this.form.missed_call_actions = [...(data.missed_call_actions || [])];
    },
    hasMissedAction(accion) {
      return this.form.missed_call_actions.includes(accion);
    },
    toggleMissedAction(accion) {
      const acciones = this.form.missed_call_actions;
      this.form.missed_call_actions = acciones.includes(accion)
        ? acciones.filter(a => a !== accion)
        : [...acciones, accion];
    },
    async load() {
      this.isLoading = true;
      try {
        const { data } = await WhatsappCallSettingsAPI.show(this.inbox.id);
        this.fill(data);
      } catch (error) {
        useAlert(this.t('LOAD_ERROR'));
      } finally {
        this.isLoading = false;
      }
    },
    async save() {
      this.isSaving = true;
      try {
        const { data } = await WhatsappCallSettingsAPI.update(
          this.inbox.id,
          this.form
        );
        this.fill(data);
        // El botón «Llamar» y el widget leen whatsapp_calls de la bandeja.
        this.$store.dispatch('inboxes/get');
        useAlert(this.t('SAVED'));
      } catch (error) {
        const mensaje =
          error &&
          error.response &&
          error.response.data &&
          error.response.data.error;
        useAlert(
          mensaje
            ? this.t('META_ERROR', { message: mensaje })
            : this.t('SAVE_ERROR')
        );
        this.load();
      } finally {
        this.isSaving = false;
      }
    },
  },
};
</script>

<template>
  <div class="mx-8">
    <woot-loading-state v-if="isLoading" :message="t('LOADING')" />

    <template v-else-if="settings">
      <p
        v-if="!settings.feature_enabled"
        class="p-4 mt-6 text-base rounded-md text-amber-800 bg-amber-50 dark:bg-amber-900/30 dark:text-amber-300"
      >
        {{ t('FEATURE_DISABLED') }}
      </p>
      <p
        v-if="settings.simulator"
        class="p-4 mt-6 text-sm rounded-md text-woot-800 bg-woot-25 dark:bg-woot-900/30 dark:text-woot-100"
      >
        {{ t('SIMULATOR_ON') }}
        <router-link :to="simulatorRoute" class="font-medium underline">
          {{ t('OPEN_SIMULATOR') }}
        </router-link>
      </p>

      <SettingsSection :title="t('ENABLE_TITLE')" :sub-title="t('ENABLE_HINT')">
        <!-- woot-switch no tiene `disabled`: sin la bandera de la cuenta no recibe clics -->
        <div
          class="flex items-center gap-3"
          :class="{
            'pointer-events-none opacity-50': !settings.feature_enabled,
          }"
        >
          <woot-switch id="whatsapp_calls_enabled" v-model="form.enabled" />
          <span class="text-sm text-slate-600 dark:text-slate-300">
            {{ form.enabled ? t('ON') : t('OFF') }}
          </span>
        </div>
        <p
          v-if="metaStatus"
          class="mt-2 mb-0 text-sm text-slate-500 dark:text-slate-400"
        >
          {{ t('META_STATUS', { status: metaStatus }) }}
        </p>
        <p
          v-if="needsManualWebhook"
          class="p-3 mt-3 mb-0 text-sm rounded-md text-amber-800 bg-amber-50 dark:bg-amber-900/30 dark:text-amber-300"
        >
          {{ t('MANUAL_WEBHOOK') }}
        </p>
      </SettingsSection>

      <SettingsSection
        :title="t('DIRECTION_TITLE')"
        :sub-title="t('DIRECTION_HINT')"
      >
        <select v-model="form.direction" :disabled="!form.enabled">
          <option value="both">{{ t('DIRECTION.BOTH') }}</option>
          <option value="inbound">{{ t('DIRECTION.INBOUND') }}</option>
          <option value="outbound">{{ t('DIRECTION.OUTBOUND') }}</option>
        </select>
      </SettingsSection>

      <SettingsSection :title="t('RING_TITLE')" :sub-title="t('RING_HINT')">
        <select
          v-model="form.ring_strategy"
          :disabled="!form.enabled || form.direction === 'outbound'"
        >
          <option value="cascade">{{ t('RING.CASCADE') }}</option>
          <option value="all_online">{{ t('RING.ALL_ONLINE') }}</option>
        </select>
      </SettingsSection>

      <SettingsSection
        :title="t('PERMISSION_TITLE')"
        :sub-title="t('PERMISSION_HINT')"
      >
        <textarea
          v-model="form.call_permission_request_body"
          rows="3"
          class="!h-auto"
          maxlength="1024"
          :placeholder="settings.default_permission_body"
          :disabled="!form.enabled || form.direction === 'inbound'"
        />
      </SettingsSection>

      <SettingsSection
        :title="t('RECORDING_TITLE')"
        :sub-title="t('RECORDING_HINT')"
      >
        <div
          class="flex items-center gap-3"
          :class="{ 'pointer-events-none opacity-50': !form.enabled }"
        >
          <woot-switch
            id="whatsapp_calls_recording"
            v-model="form.recording_enabled"
          />
          <span class="text-sm text-slate-600 dark:text-slate-300">
            {{
              form.recording_enabled ? t('RECORDING_ON') : t('RECORDING_OFF')
            }}
          </span>
        </div>
        <label class="mt-4">
          {{ t('RECORDING_NOTICE_LABEL') }}
          <textarea
            v-model="form.recording_notice"
            rows="2"
            class="!h-auto"
            maxlength="1024"
            :placeholder="settings.default_recording_notice"
            :disabled="!form.enabled || !form.recording_enabled"
          />
        </label>
        <p class="mt-1 mb-0 text-xs text-slate-500 dark:text-slate-400">
          {{ t('RECORDING_NOTICE_HINT') }}
        </p>
      </SettingsSection>

      <SettingsSection :title="t('MISSED_TITLE')" :sub-title="t('MISSED_HINT')">
        <fieldset :disabled="!acceptsInbound" class="flex flex-col gap-3">
          <div v-for="accion in missedActions" :key="accion">
            <label class="flex items-start gap-2 mb-0">
              <input
                type="checkbox"
                class="mt-1"
                :checked="hasMissedAction(accion)"
                @change="toggleMissedAction(accion)"
              />
              <span>
                <span class="block text-sm font-medium">
                  {{ t(`MISSED.${accion.toUpperCase()}`) }}
                </span>
                <span class="block text-xs text-slate-500 dark:text-slate-400">
                  {{ t(`MISSED.${accion.toUpperCase()}_HINT`) }}
                </span>
              </span>
            </label>
            <div
              v-if="hasMissedAction(accion) && accion !== 'note'"
              class="mt-2 ml-6"
            >
              <template v-if="accion === 'label'">
                <input
                  v-model="form.missed_call_label"
                  type="text"
                  list="whatsapp-calls-labels"
                  :placeholder="settings.default_missed_call_label"
                />
                <datalist id="whatsapp-calls-labels">
                  <option
                    v-for="etiqueta in missedOptions.labels"
                    :key="etiqueta"
                    :value="etiqueta"
                  />
                </datalist>
              </template>
              <select
                v-else-if="accion === 'ticket'"
                v-model="form.missed_call_case_type_id"
              >
                <option :value="null">{{ t('MISSED.CHOOSE_TYPE') }}</option>
                <option
                  v-for="tipo in missedOptions.case_types"
                  :key="tipo.id"
                  :value="tipo.id"
                >
                  {{ tipo.name }}
                </option>
              </select>
              <select
                v-else-if="accion === 'tracking'"
                v-model="form.missed_call_campaign_id"
              >
                <option :value="null">{{ t('MISSED.CHOOSE_CAMPAIGN') }}</option>
                <option
                  v-for="campana in missedOptions.campaigns"
                  :key="campana.id"
                  :value="campana.id"
                >
                  {{ campana.name }}
                </option>
              </select>
              <textarea
                v-else-if="accion === 'auto_reply'"
                v-model="form.missed_call_auto_reply"
                rows="2"
                class="!h-auto"
                maxlength="1024"
                :placeholder="settings.default_missed_call_auto_reply"
              />
            </div>
          </div>
        </fieldset>
      </SettingsSection>

      <SettingsSection :show-border="false">
        <woot-button
          :is-loading="isSaving"
          :is-disabled="!settings.feature_enabled"
          @click="save"
        >
          {{ t('SAVE') }}
        </woot-button>
      </SettingsSection>
    </template>
  </div>
</template>

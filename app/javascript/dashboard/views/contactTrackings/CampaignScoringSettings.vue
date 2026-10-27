<!--
  prospeccion P4 (docs/prospeccion_estudio.md §10.11) — modal «Puntuación».
  Los pesos de cada criterio (sugeridos de §8.2) y las reglas del Perfil: qué etiquetas o
  qué valor de un atributo hacen que el contacto se parezca al cliente ideal. Por ahora la
  puntuación solo ordena y prioriza. Molde nativo de modal (AddAgent.vue); el padre lo
  envuelve en <woot-modal size="medium">.
-->
<script>
import { useAlert } from 'dashboard/composables';
import WootSubmitButton from 'dashboard/components/buttons/FormSubmitButton.vue';
import TrackingCampaignsAPI from 'dashboard/api/trackingCampaigns';

const PROFILE = ['industry', 'size', 'decider'];
const INTEREST = [
  'replied',
  'asked_price',
  'asked_meeting',
  'no_reply_30',
  'not_now',
];
const toList = text =>
  text
    .split(',')
    .map(item => item.trim())
    .filter(Boolean);

export default {
  name: 'CampaignScoringSettings',
  components: { WootSubmitButton },
  props: {
    campaign: { type: Object, required: true },
  },
  emits: ['saved', 'close'],
  data() {
    return {
      profileKeys: PROFILE,
      interestKeys: INTEREST,
      weights: {},
      rules: {},
      campaigns: [],
      copyFrom: '',
      saving: false,
    };
  },
  computed: {
    otherCampaigns() {
      return this.campaigns.filter(c => c.id !== this.campaign.id);
    },
  },
  created() {
    this.fill(this.campaign.scoring);
  },
  async mounted() {
    try {
      const { data } = await TrackingCampaignsAPI.getOptions();
      this.campaigns = data;
    } catch {
      this.campaigns = [];
    }
  },
  methods: {
    // La configuración del servidor → campos (listas como texto separado por comas).
    fill(scoring) {
      this.weights = { ...scoring.weights };
      this.rules = PROFILE.reduce((acc, key) => {
        const rule = scoring.rules[key];
        acc[key] = {
          labels: rule.labels.join(', '),
          attributeKey: rule.attribute_key,
          attributeValues: rule.attribute_values.join(', '),
        };
        return acc;
      }, {});
    },
    payload() {
      return {
        scoring: {
          weights: this.weights,
          rules: PROFILE.reduce((acc, key) => {
            const rule = this.rules[key];
            acc[key] = {
              labels: toList(rule.labels),
              attribute_key: rule.attributeKey.trim(),
              attribute_values: toList(rule.attributeValues),
            };
            return acc;
          }, {}),
        },
      };
    },
    async send(body, done) {
      this.saving = true;
      try {
        const { data } = await TrackingCampaignsAPI.updateScoring(
          this.campaign.id,
          body
        );
        this.fill(data);
        this.$emit('saved', data);
        useAlert(this.$t(`TRACKING_CAMPAIGN_DETAIL.SCORING.${done}`));
        return true;
      } catch {
        useAlert(this.$t('TRACKING_CAMPAIGN_DETAIL.SCORING.ERROR'));
        return false;
      } finally {
        this.saving = false;
      }
    },
    async save() {
      if (await this.send(this.payload(), 'SAVED')) this.$emit('close');
    },
    reset() {
      this.send({ reset: true }, 'RESET_DONE');
    },
    copy() {
      if (!this.copyFrom) return;
      this.send({ copy_from_campaign_id: this.copyFrom }, 'COPIED');
      this.copyFrom = '';
    },
  },
};
</script>

<template>
  <div class="flex flex-col h-auto">
    <woot-modal-header
      :header-title="$t('TRACKING_CAMPAIGN_DETAIL.SCORING.TITLE')"
      :header-content="$t('TRACKING_CAMPAIGN_DETAIL.SCORING.DESC')"
    />
    <form class="flex flex-col items-start w-full" @submit.prevent="save">
      <ol
        class="w-full mb-3 ml-4 space-y-0.5 text-sm list-decimal text-slate-600 dark:text-slate-300"
      >
        <li>{{ $t('TRACKING_CAMPAIGN_DETAIL.SCORING.HOW_1') }}</li>
        <li>{{ $t('TRACKING_CAMPAIGN_DETAIL.SCORING.HOW_2') }}</li>
        <li>{{ $t('TRACKING_CAMPAIGN_DETAIL.SCORING.HOW_3') }}</li>
        <li>{{ $t('TRACKING_CAMPAIGN_DETAIL.SCORING.HOW_4') }}</li>
      </ol>

      <span class="text-sm font-semibold text-slate-700 dark:text-slate-200">
        {{ $t('TRACKING_CAMPAIGN_DETAIL.SCORING.PROFILE') }}
      </span>
      <div
        v-for="key in profileKeys"
        :key="key"
        class="grid w-full grid-cols-[10rem_5rem_1fr_9rem_1fr] gap-x-3 items-end"
      >
        <span class="pb-4 text-sm text-slate-700 dark:text-slate-200">
          {{ $t(`TRACKING_CAMPAIGN_DETAIL.SCORING.CRITERIA.${key}`) }}
        </span>
        <label>
          {{ $t('TRACKING_CAMPAIGN_DETAIL.SCORING.POINTS') }}
          <input
            v-model.number="weights[key]"
            type="number"
            min="-50"
            max="50"
          />
        </label>
        <label>
          {{ $t('TRACKING_CAMPAIGN_DETAIL.SCORING.LABELS') }}
          <input
            v-model="rules[key].labels"
            type="text"
            :placeholder="
              $t('TRACKING_CAMPAIGN_DETAIL.SCORING.LABELS_PLACEHOLDER')
            "
          />
        </label>
        <label>
          {{ $t('TRACKING_CAMPAIGN_DETAIL.SCORING.ATTRIBUTE') }}
          <input
            v-model="rules[key].attributeKey"
            type="text"
            :placeholder="
              $t('TRACKING_CAMPAIGN_DETAIL.SCORING.ATTRIBUTE_PLACEHOLDER')
            "
          />
        </label>
        <label>
          {{ $t('TRACKING_CAMPAIGN_DETAIL.SCORING.VALUES') }}
          <input
            v-model="rules[key].attributeValues"
            type="text"
            :placeholder="
              $t('TRACKING_CAMPAIGN_DETAIL.SCORING.VALUES_PLACEHOLDER')
            "
          />
        </label>
      </div>

      <span class="text-sm font-semibold text-slate-700 dark:text-slate-200">
        {{ $t('TRACKING_CAMPAIGN_DETAIL.SCORING.INTEREST') }}
      </span>
      <div class="grid w-full grid-cols-5 gap-x-3">
        <label v-for="key in interestKeys" :key="key">
          {{ $t(`TRACKING_CAMPAIGN_DETAIL.SCORING.CRITERIA.${key}`) }}
          <input
            v-model.number="weights[key]"
            type="number"
            min="-50"
            max="50"
          />
        </label>
      </div>

      <div class="grid w-full grid-cols-[1fr_auto] gap-x-3 items-end">
        <label>
          {{ $t('TRACKING_CAMPAIGN_DETAIL.SCORING.COPY_FROM') }}
          <select v-model="copyFrom" @change="copy">
            <option value="">
              {{ $t('TRACKING_CAMPAIGN_DETAIL.SCORING.COPY_PLACEHOLDER') }}
            </option>
            <option v-for="c in otherCampaigns" :key="c.id" :value="c.id">
              {{ c.name }}
            </option>
          </select>
        </label>
        <button class="mb-4 button clear" @click.prevent="reset">
          {{ $t('TRACKING_CAMPAIGN_DETAIL.SCORING.RESET') }}
        </button>
      </div>

      <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
        <div class="w-full">
          <WootSubmitButton
            :disabled="saving"
            :button-text="$t('TRACKING_CAMPAIGN_DETAIL.SCORING.SAVE')"
            :loading="saving"
          />
          <button class="button clear" @click.prevent="$emit('close')">
            {{ $t('TRACKING_CAMPAIGN_DETAIL.SCORING.CANCEL') }}
          </button>
        </div>
      </div>
    </form>
  </div>
</template>

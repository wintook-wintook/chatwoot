<!--
  feat/plantillas_whatsapp_mejoras — BORRAR UNA PLANTILLA, SABIENDO QUÉ SE ROMPE
  Dice qué pasa según el caso (un borrador solo se borra aquí; la que está en Meta se borra
  allá y Meta no deja reusar el nombre 30 días) y dónde se usa (Whatsapp::TemplateUsage).
  No impide borrar: si está en uso pide marcar una casilla. Si no se pudo revisar el uso
  también la pide, porque no se sabe qué se rompería. Molde nativo: settings/agents/AddAgent.vue.
-->
<script>
import WhatsappTemplatesAPI from 'dashboard/api/whatsapp/templates';
import { isLocalDraft } from './templateEditor';
import { templateInUse } from './templateScreen';

export default {
  props: {
    template: {
      type: Object,
      required: true,
    },
    deleting: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['close', 'confirm'],
  data() {
    return {
      usage: null,
      loading: true,
      usageFailed: false,
      acknowledged: false,
    };
  },
  computed: {
    isDraft() {
      return isLocalDraft(this.template);
    },
    inUse() {
      return templateInUse(this.usage);
    },
    needsAcknowledge() {
      return this.inUse || this.usageFailed;
    },
    canDelete() {
      if (this.loading || this.deleting) return false;
      return !this.needsAcknowledge || this.acknowledged;
    },
    description() {
      return this.isDraft
        ? this.$t('WHATSAPP_TEMPLATE_DELETE.DRAFT')
        : this.$t('WHATSAPP_TEMPLATE_DELETE.IN_META');
    },
    confirmLabel() {
      return this.needsAcknowledge
        ? this.$t('WHATSAPP_TEMPLATE_DELETE.CONFIRM_ANYWAY')
        : this.$t('WHATSAPP_TEMPLATE_DELETE.CONFIRM');
    },
  },
  async mounted() {
    try {
      const { data } = await WhatsappTemplatesAPI.usage(this.template.id);
      this.usage = data;
    } catch {
      this.usageFailed = true;
    } finally {
      this.loading = false;
    }
  },
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="
        $t('WHATSAPP_TEMPLATE_DELETE.TITLE', { name: template.name })
      "
      :header-content="description"
    />
    <form
      class="flex flex-col items-start w-full"
      @submit.prevent="$emit('confirm')"
    >
      <p v-if="loading" class="mb-2 text-sm text-slate-500">
        {{ $t('WHATSAPP_TEMPLATE_DELETE.CHECKING') }}
      </p>
      <p v-else-if="usageFailed" class="mb-2 text-sm text-amber-700">
        {{ $t('WHATSAPP_TEMPLATE_DELETE.USAGE_FAILED') }}
      </p>
      <div v-else-if="inUse" class="w-full mb-2 text-sm">
        <p class="mb-1 font-medium text-amber-700 dark:text-amber-400">
          {{ $t('WHATSAPP_TEMPLATE_DELETE.IN_USE') }}
        </p>
        <ul class="pl-5 mb-2 list-disc text-slate-700 dark:text-slate-200">
          <li v-if="usage.agents.length">
            {{ $t('WHATSAPP_TEMPLATE_DELETE.AGENTS') }}
            <template v-for="(agente, i) in usage.agents">
              <span v-if="i" :key="`s-${agente.id}`">, </span>
              <router-link
                :key="`a-${agente.id}`"
                class="underline"
                :to="{
                  name: 'contact_trackings_agent',
                  params: { templateId: agente.id },
                }"
              >
                {{ agente.name }}
              </router-link>
            </template>
          </li>
          <li v-if="usage.trackings_count">
            {{
              $t('WHATSAPP_TEMPLATE_DELETE.TRACKINGS', {
                count: usage.trackings_count,
              })
            }}
          </li>
          <li v-if="usage.campaigns.length">
            {{ $t('WHATSAPP_TEMPLATE_DELETE.CAMPAIGNS') }}
            <template v-for="(campana, i) in usage.campaigns">
              <span v-if="i" :key="`c-${campana.id}`">, </span>
              <router-link
                :key="`d-${campana.id}`"
                class="underline"
                :to="{
                  name: 'contact_trackings_campaign_detail',
                  params: { campaignId: campana.id },
                }"
              >
                {{ campana.name }}
              </router-link>
            </template>
          </li>
          <li v-if="usage.scheduled_count">
            {{
              $t('WHATSAPP_TEMPLATE_DELETE.SCHEDULED', {
                count: usage.scheduled_count,
              })
            }}
          </li>
          <li v-if="usage.portals.length">
            {{
              $t('WHATSAPP_TEMPLATE_DELETE.PORTALS', {
                names: usage.portals.map(p => p.name).join(', '),
              })
            }}
          </li>
        </ul>
        <p class="mb-0 text-slate-600 dark:text-slate-300">
          {{ $t('WHATSAPP_TEMPLATE_DELETE.WILL_FAIL') }}
        </p>
      </div>
      <label v-if="needsAcknowledge" class="flex items-start gap-2 mb-2">
        <input v-model="acknowledged" type="checkbox" class="mt-1 !mb-0" />
        <span>{{ $t('WHATSAPP_TEMPLATE_DELETE.ACKNOWLEDGE') }}</span>
      </label>
      <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
        <woot-button variant="clear" type="button" @click="$emit('close')">
          {{ $t('WHATSAPP_TEMPLATE_DELETE.CANCEL') }}
        </woot-button>
        <woot-button
          color-scheme="alert"
          :is-disabled="!canDelete"
          :is-loading="deleting"
          @click.prevent="$emit('confirm')"
        >
          {{ confirmLabel }}
        </woot-button>
      </div>
    </form>
  </div>
</template>

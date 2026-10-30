<!--
  feat/plantillas_whatsapp_mejoras F10.4 — LA FICHA DE UNA PLANTILLA (/whatsapp-templates/:id)
  Plan: docs/plantillas_whatsapp_mejoras_plan.md §7.12. El clic en una plantilla de la
  lista abre esto (antes solo había editar): el estado en Meta como pasos (y, si la
  rechazaron, el motivo con qué hacer), la calidad, dónde se puede mandar, sus datos y la
  vista previa. Desde aquí: Ver en Meta, Duplicar (abre el editor con todo copiado) y
  Editar. Mismo encabezado nativo que la lista y el editor (SettingsLayout +
  BaseSettingsHeader). Lógica pura en templateScreen.js / templateEditor.js.
-->
<script>
import { mapGetters } from 'vuex';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import TemplatePreview from './TemplatePreview.vue';
import { formFromTemplate, isLocalDraft } from './templateEditor';
import {
  metaManagerUrl,
  rejectionKey,
  sendability,
  statusSteps,
} from './templateScreen';

const STEP_ICONS = {
  done: 'checkmark-circle',
  current: 'clock',
  pending: 'status',
  failed: 'dismiss-circle',
  warning: 'warning',
};

export default {
  components: { BaseSettingsHeader, SettingsLayout, TemplatePreview },
  data() {
    return {
      loading: false,
      notFound: false,
    };
  },
  computed: {
    ...mapGetters({
      templates: 'whatsappTemplates/getTemplates',
      inboxes: 'inboxes/getInboxes',
    }),
    templateId() {
      return Number(this.$route.params.templateId) || null;
    },
    template() {
      return this.templates.find(t => t.id === this.templateId) || null;
    },
    inbox() {
      if (!this.template) return null;
      return (
        this.inboxes.find(
          i =>
            i.channel_type === 'Channel::Whatsapp' &&
            i.channel_id === this.template.channel_whatsapp_id
        ) || null
      );
    },
    form() {
      return this.template ? formFromTemplate(this.template) : null;
    },
    title() {
      return this.template ? this.template.name : '';
    },
    description() {
      if (!this.template) return '';
      return [
        this.$t(
          `WHATSAPP_TEMPLATE_EDITOR.CATEGORIES.${this.template.category}`
        ),
        this.template.language,
        this.inbox ? this.inbox.name : '',
      ]
        .filter(Boolean)
        .join(' · ');
    },
    steps() {
      return statusSteps(this.template.status).map(paso => ({
        ...paso,
        icon: STEP_ICONS[paso.state],
        label: this.$t(`WHATSAPP_TEMPLATE_DETAIL.STEPS.${paso.key}`),
      }));
    },
    submittedAt() {
      const fecha = this.template && this.template.last_submitted_at;
      return fecha ? new Date(fecha).toLocaleString() : '';
    },
    rejection() {
      const motivo = this.template && this.template.rejection_reason;
      if (!motivo || this.template.status !== 'REJECTED') return null;
      const clave = rejectionKey(motivo);
      return {
        raw: motivo,
        text: clave
          ? this.$t(`WHATSAPP_TEMPLATE_DETAIL.REJECTIONS.${clave}`)
          : this.$t('WHATSAPP_TEMPLATE_DETAIL.REJECTIONS.OTHER'),
      };
    },
    quality() {
      const nivel = this.template && this.template.quality_score;
      return nivel
        ? {
            level: nivel,
            label: this.$t(`WHATSAPP_TEMPLATE_DETAIL.QUALITY.${nivel}`),
          }
        : null;
    },
    sendable() {
      return sendability(this.template, this.inbox);
    },
    trackingsLabel() {
      const estado = this.sendable.trackings;
      return estado
        ? this.$t(
            `WHATSAPP_TEMPLATE_DETAIL.SEND.TRACKINGS_${estado.toUpperCase()}`
          )
        : '';
    },
    details() {
      const t = this.template;
      const botones = t.buttons || [];
      const variables =
        ((t.sample_values || {}).body || []).length +
        ((t.sample_values || {}).header || []).length;
      return [
        {
          key: 'HEADER',
          value: this.$t(
            `WHATSAPP_TEMPLATE_EDITOR.HEADER_TYPES.${(
              t.header_type || 'none'
            ).toUpperCase()}`
          ),
        },
        { key: 'VARIABLES', value: String(variables) },
        { key: 'BUTTONS', value: String(botones.length) },
        { key: 'META_ID', value: t.meta_template_id || '—' },
      ];
    },
    metaUrl() {
      return metaManagerUrl(this.inbox);
    },
    canEdit() {
      return Boolean(this.template && this.template.editable);
    },
    editLabel() {
      return isLocalDraft(this.template)
        ? this.$t('WHATSAPP_TEMPLATE_DETAIL.ACTIONS.CONTINUE_DRAFT')
        : this.$t('WHATSAPP_TEMPLATE_DETAIL.ACTIONS.EDIT');
    },
  },
  watch: {
    templateId() {
      this.load();
    },
  },
  mounted() {
    this.$store.dispatch('inboxes/get');
    this.load();
  },
  activated() {
    this.load();
  },
  methods: {
    async load() {
      this.notFound = false;
      if (this.template) return;
      this.loading = true;
      try {
        await this.$store.dispatch('whatsappTemplates/fetch');
        this.notFound = !this.template;
      } finally {
        this.loading = false;
      }
    },
    goToList() {
      this.$router.push({ name: 'whatsapp_templates_index' });
    },
    openInMeta() {
      if (this.metaUrl) window.open(this.metaUrl, '_blank', 'noopener');
    },
    duplicate() {
      this.$router.push({
        name: 'whatsapp_templates_new',
        query: { from: this.template.id },
      });
    },
    edit() {
      this.$router.push({
        name: 'whatsapp_templates_edit',
        params: { templateId: this.template.id },
      });
    },
    stepClass(paso) {
      return `status-step--${paso.state}`;
    },
  },
};
</script>

<template>
  <SettingsLayout
    :is-loading="loading"
    :loading-message="$t('WHATSAPP_TEMPLATE_EDITOR.LOADING')"
    :no-records-found="notFound"
    :no-records-message="$t('WHATSAPP_TEMPLATE_EDITOR.NOT_FOUND')"
  >
    <template #header>
      <BaseSettingsHeader :title="title" :description="description">
        <template #actions>
          <woot-button variant="clear" icon="chevron-left" @click="goToList">
            {{ $t('WHATSAPP_TEMPLATE_EDITOR.HEADER') }}
          </woot-button>
          <woot-button
            v-if="metaUrl"
            variant="hollow"
            icon="open"
            @click="openInMeta"
          >
            {{ $t('WHATSAPP_TEMPLATE_DETAIL.ACTIONS.META') }}
          </woot-button>
          <woot-button variant="hollow" icon="copy" @click="duplicate">
            {{ $t('WHATSAPP_TEMPLATE_DETAIL.ACTIONS.DUPLICATE') }}
          </woot-button>
          <woot-button
            icon="edit"
            :is-disabled="!canEdit"
            :title="
              canEdit ? '' : $t('WHATSAPP_TEMPLATE_DETAIL.ACTIONS.EDIT_LOCKED')
            "
            @click="edit"
          >
            {{ editLabel }}
          </woot-button>
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <div
        v-if="template"
        class="grid w-full grid-cols-1 gap-6 lg:grid-cols-[minmax(0,1fr)_22rem] items-start"
      >
        <div class="flex flex-col gap-4 min-w-0">
          <!-- Estado en Meta -->
          <div class="detail-card">
            <span class="detail-card__title">
              {{ $t('WHATSAPP_TEMPLATE_DETAIL.STATUS_TITLE') }}
            </span>
            <div class="flex flex-wrap items-center gap-2">
              <template v-for="(paso, i) in steps">
                <span
                  :key="`p-${paso.key}`"
                  class="status-step"
                  :class="stepClass(paso)"
                >
                  <fluent-icon :icon="paso.icon" size="16" />
                  {{ paso.label }}
                </span>
                <fluent-icon
                  v-if="i < steps.length - 1"
                  :key="`f-${paso.key}`"
                  icon="chevron-right"
                  size="14"
                  class="text-slate-300 dark:text-slate-600"
                />
              </template>
            </div>
            <p v-if="submittedAt" class="mt-2 mb-0 text-xs text-slate-500">
              {{
                $t('WHATSAPP_TEMPLATE_DETAIL.SUBMITTED_AT', {
                  date: submittedAt,
                })
              }}
            </p>
            <div v-if="rejection" class="detail-alert detail-alert--error">
              <strong>
                {{
                  $t('WHATSAPP_TEMPLATE_DETAIL.REJECTED_BECAUSE', {
                    reason: rejection.raw,
                  })
                }}
              </strong>
              <span>{{ rejection.text }}</span>
            </div>
            <div
              v-if="template.submission_error"
              class="detail-alert detail-alert--warning"
            >
              <strong>{{ $t('WHATSAPP_TEMPLATE_DETAIL.LAST_ERROR') }}</strong>
              <span>{{ template.submission_error }}</span>
            </div>
          </div>

          <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
            <!-- Se puede enviar -->
            <div class="detail-card">
              <span class="detail-card__title">
                {{ $t('WHATSAPP_TEMPLATE_DETAIL.SEND.TITLE') }}
              </span>
              <p
                v-if="sendable.conversation === null"
                class="mb-0 text-sm text-slate-500"
              >
                {{ $t('WHATSAPP_TEMPLATE_DETAIL.SEND.NOT_YET') }}
              </p>
              <template v-else>
                <p class="flex items-center gap-2 mb-1 text-sm">
                  <fluent-icon
                    :icon="
                      sendable.conversation
                        ? 'checkmark-circle'
                        : 'dismiss-circle'
                    "
                    size="16"
                    :class="
                      sendable.conversation
                        ? 'text-green-600'
                        : 'text-slate-400'
                    "
                  />
                  {{ $t('WHATSAPP_TEMPLATE_DETAIL.SEND.CONVERSATION') }}
                </p>
                <p class="flex items-center gap-2 mb-0 text-sm">
                  <fluent-icon
                    :icon="
                      sendable.trackings === 'ok'
                        ? 'checkmark-circle'
                        : sendable.trackings === 'missing_file'
                        ? 'warning'
                        : 'dismiss-circle'
                    "
                    size="16"
                    :class="{
                      'text-green-600': sendable.trackings === 'ok',
                      'text-amber-600': sendable.trackings === 'missing_file',
                      'text-slate-400': sendable.trackings === 'no',
                    }"
                  />
                  {{ trackingsLabel }}
                </p>
              </template>
            </div>

            <!-- Calidad y datos -->
            <div class="detail-card">
              <span class="detail-card__title">
                {{ $t('WHATSAPP_TEMPLATE_DETAIL.DETAILS_TITLE') }}
              </span>
              <p class="flex items-center gap-2 mb-1 text-sm">
                <span class="text-slate-500">
                  {{ $t('WHATSAPP_TEMPLATE_DETAIL.QUALITY.TITLE') }}
                </span>
                <span v-if="quality" class="inline-flex items-center gap-1">
                  <span
                    class="w-2 h-2 rounded-full"
                    :class="{
                      'bg-green-500': quality.level === 'GREEN',
                      'bg-amber-500': quality.level === 'YELLOW',
                      'bg-red-500': quality.level === 'RED',
                    }"
                  />
                  {{ quality.label }}
                </span>
                <span v-else class="text-slate-400">
                  {{ $t('WHATSAPP_TEMPLATE_DETAIL.QUALITY.NONE') }}
                </span>
              </p>
              <p
                v-for="dato in details"
                :key="dato.key"
                class="flex items-center gap-2 mb-1 text-sm"
              >
                <span class="text-slate-500">
                  {{ $t(`WHATSAPP_TEMPLATE_DETAIL.FIELDS.${dato.key}`) }}
                </span>
                <span class="truncate">{{ dato.value }}</span>
              </p>
            </div>
          </div>
        </div>

        <aside class="flex flex-col gap-3 pt-2">
          <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
            {{ $t('WHATSAPP_TEMPLATE_EDITOR.SECTIONS.PREVIEW') }}
          </span>
          <TemplatePreview :form="form" />
        </aside>
      </div>
    </template>
  </SettingsLayout>
</template>

<style scoped lang="scss">
.detail-card {
  @apply flex flex-col p-4 rounded-lg border border-solid border-slate-100 dark:border-slate-700;
}

.detail-card__title {
  @apply mb-3 text-sm font-medium text-slate-700 dark:text-slate-200;
}

.status-step {
  @apply inline-flex items-center gap-1 px-2 py-1 text-xs font-medium rounded-full bg-slate-100 text-slate-500 dark:bg-slate-700 dark:text-slate-300;
}

.status-step--done {
  @apply bg-green-100 text-green-700 dark:bg-green-800 dark:text-green-100;
}

.status-step--current {
  @apply bg-amber-100 text-amber-700 dark:bg-amber-800 dark:text-amber-100;
}

.status-step--failed {
  @apply bg-red-100 text-red-700 dark:bg-red-800 dark:text-red-100;
}

.status-step--warning {
  @apply bg-amber-100 text-amber-700 dark:bg-amber-800 dark:text-amber-100;
}

.detail-alert {
  @apply flex flex-col gap-1 p-3 mt-3 text-sm rounded-lg;
}

.detail-alert--error {
  @apply bg-red-50 text-red-700 dark:bg-red-900/30 dark:text-red-200;
}

.detail-alert--warning {
  @apply bg-amber-50 text-amber-700 dark:bg-amber-900/30 dark:text-amber-200;
}
</style>

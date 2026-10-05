<!--
  ================================================================================
  proyecto@publicar_prompts (F3)
  ================================================================================
  Componente: PublishPromptModal.vue
  Descripción: publicar (o sacar versión nueva / despublicar) el prompt de un Agente
               IA para que otras cuentas lo bajen desde su Asistente. Solo lo abre el
               usuario con can_publish_prompts; la API responde 403 a cualquier otro.
               Muestra lo que NO se publica y lo que tendrá que configurar quien lo baje.
  Plan: docs/publicar_prompts_plan.md
  ================================================================================
-->

<script>
import { useAlert } from 'dashboard/composables';
import TrackingTemplatesAPI from 'dashboard/api/trackingTemplates';

export default {
  props: {
    show: { type: Boolean, default: false },
    template: { type: Object, default: null },
  },
  emits: ['close', 'changed'],
  data() {
    return {
      isLoading: false,
      isSaving: false,
      publication: null,
      requirements: [],
      categories: [],
      form: { title: '', description: '', category: '' },
    };
  },
  computed: {
    isPublished() {
      return !!this.publication && this.publication.status === 'published';
    },
    statusText() {
      if (!this.publication) return '';
      const key = this.isPublished ? 'STATUS_PUBLISHED' : 'STATUS_UNPUBLISHED';
      return this.$t(`TRACKING_TEMPLATES.PUBLISH.${key}`, {
        version: this.publication.version,
        downloads: this.publication.downloads_count,
      });
    },
    submitText() {
      return this.isPublished
        ? this.$t('TRACKING_TEMPLATES.PUBLISH.SUBMIT_NEW_VERSION')
        : this.$t('TRACKING_TEMPLATES.PUBLISH.SUBMIT');
    },
    isTitleValid() {
      const length = this.form.title.trim().length;
      return length >= 2 && length <= 100;
    },
  },
  watch: {
    show(visible) {
      if (visible) this.load();
    },
  },
  methods: {
    async load() {
      if (!this.template) return;
      this.isLoading = true;
      try {
        const { data } = await TrackingTemplatesAPI.getPublication(
          this.template.id
        );
        this.apply(data);
      } catch (error) {
        useAlert(this.$t('TRACKING_TEMPLATES.PUBLISH.API.LOAD_ERROR'));
        this.$emit('close');
      } finally {
        this.isLoading = false;
      }
    },
    apply(data) {
      this.publication = data.publication;
      this.requirements = data.preview.requirements || [];
      this.categories = data.categories || [];
      const pub = data.publication || {};
      this.form = {
        title: pub.title || this.template.name,
        description: pub.description || '',
        category: pub.category || '',
      };
    },
    requirementText(req) {
      const kind = this.$t(
        `TRACKING_TEMPLATES.PUBLISH.REQUIREMENTS.${req.kind.toUpperCase()}`
      );
      return req.name ? `${kind}: ${req.name}` : kind;
    },
    categoryText(category) {
      return this.$t(
        `TRACKING_TEMPLATES.PUBLISH.CATEGORIES.${category.toUpperCase()}`
      );
    },
    async publish() {
      if (!this.isTitleValid) return;
      await this.save(
        () => TrackingTemplatesAPI.publish(this.template.id, this.form),
        'PUBLISHED'
      );
    },
    async unpublish() {
      await this.save(
        () => TrackingTemplatesAPI.unpublish(this.template.id),
        'UNPUBLISHED'
      );
    },
    async save(request, successKey) {
      this.isSaving = true;
      try {
        const { data } = await request();
        this.apply(data);
        useAlert(this.$t(`TRACKING_TEMPLATES.PUBLISH.API.${successKey}`));
        this.$emit('changed');
        this.$emit('close');
      } catch (error) {
        const message =
          (error.response && error.response.data.message) ||
          this.$t('TRACKING_TEMPLATES.PUBLISH.API.SAVE_ERROR');
        useAlert(message);
      } finally {
        this.isSaving = false;
      }
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="() => $emit('close')" size="medium">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="$t('TRACKING_TEMPLATES.PUBLISH.TITLE')"
        :header-content="$t('TRACKING_TEMPLATES.PUBLISH.DESCRIPTION')"
      />

      <div v-if="isLoading" class="px-8 pb-6">
        <woot-loading-state :message="$t('TRACKING_TEMPLATES.LOADING')" />
      </div>

      <form
        v-else
        class="flex flex-col gap-3 px-8 pb-6"
        @submit.prevent="publish"
      >
        <div v-if="publication" class="flex items-center gap-2">
          <woot-label
            small
            :title="statusText"
            :color-scheme="isPublished ? 'success' : 'secondary'"
          />
        </div>

        <label :class="{ error: form.title && !isTitleValid }">
          {{ $t('TRACKING_TEMPLATES.PUBLISH.FORM.TITLE') }}
          <input
            v-model="form.title"
            type="text"
            class="!mb-0"
            maxlength="100"
            :placeholder="template ? template.name : ''"
          />
        </label>

        <label>
          {{ $t('TRACKING_TEMPLATES.PUBLISH.FORM.DESCRIPTION') }}
          <textarea
            v-model="form.description"
            rows="3"
            class="!mb-0"
            maxlength="500"
            :placeholder="
              $t('TRACKING_TEMPLATES.PUBLISH.FORM.DESCRIPTION_PLACEHOLDER')
            "
          />
        </label>

        <label>
          {{ $t('TRACKING_TEMPLATES.PUBLISH.FORM.CATEGORY') }}
          <select v-model="form.category" class="!mb-0">
            <option value="">
              {{ $t('TRACKING_TEMPLATES.PUBLISH.FORM.NO_CATEGORY') }}
            </option>
            <option
              v-for="category in categories"
              :key="category"
              :value="category"
            >
              {{ categoryText(category) }}
            </option>
          </select>
        </label>

        <div
          class="rounded-md border border-slate-100 dark:border-slate-700 bg-slate-25 dark:bg-slate-800 p-3 text-sm text-slate-700 dark:text-slate-200"
        >
          <p class="mb-2">
            {{ $t('TRACKING_TEMPLATES.PUBLISH.NOT_PUBLISHED') }}
          </p>
          <p v-if="requirements.length" class="mb-1 font-medium">
            {{ $t('TRACKING_TEMPLATES.PUBLISH.REQUIREMENTS_TITLE') }}
          </p>
          <ul
            v-if="requirements.length"
            class="mb-0 list-disc ltr:ml-5 rtl:mr-5"
          >
            <li v-for="req in requirements" :key="req.kind + (req.name || '')">
              {{ requirementText(req) }}
            </li>
          </ul>
          <p v-else class="mb-0">
            {{ $t('TRACKING_TEMPLATES.PUBLISH.NO_REQUIREMENTS') }}
          </p>
        </div>

        <div class="flex items-center justify-between gap-2 pt-2">
          <woot-button
            v-if="isPublished"
            type="button"
            variant="clear"
            color-scheme="alert"
            :is-loading="isSaving"
            @click="unpublish"
          >
            {{ $t('TRACKING_TEMPLATES.PUBLISH.UNPUBLISH') }}
          </woot-button>
          <span v-else />
          <div class="flex items-center gap-2">
            <woot-button
              type="button"
              variant="clear"
              color-scheme="secondary"
              @click="$emit('close')"
            >
              {{ $t('TRACKING_TEMPLATES.PUBLISH.CANCEL') }}
            </woot-button>
            <woot-button
              type="submit"
              :is-loading="isSaving"
              :is-disabled="!isTitleValid"
            >
              {{ submitText }}
            </woot-button>
          </div>
        </div>
      </form>
    </div>
  </woot-modal>
</template>

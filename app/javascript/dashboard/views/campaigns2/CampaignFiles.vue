<!--
  Campaña con Vendedor IA — «Imágenes y archivos de esta oferta»: la foto del producto en promoción, el flyer del
  evento… Cada uno con su descripción (el vendedor no ve la imagen) y cuándo va: en el toque N, cuando muestre
  interés, cuando lo pida o al confirmar (Invitar). Los generales (catálogo, presentación) siguen en el vendedor.
  motor2_campaigns/:id/files (Motor2Campaigns::FilesController). Para subir, la campaña se guarda primero.
-->
<script>
import { useAlert } from 'dashboard/composables';
import Motor2CampaignsAPI from 'dashboard/api/motor2Campaigns';

const IMAGE_TYPES = ['image/jpeg', 'image/png'];
const MAX_FILES = 10;

export default {
  name: 'CampaignFiles',
  props: {
    campaignId: { type: [Number, String], default: null },
    save: { type: Function, required: true },
    attempts: { type: Number, default: 1 },
    kind: { type: String, default: 'offer' },
  },
  data() {
    return { files: [], uploading: false };
  },
  computed: {
    touches() {
      return Array.from({ length: this.attempts }, (_, i) => i + 1);
    },
    flags() {
      if (this.kind === 'survey') return [];
      return this.kind === 'invite' ? ['confirm', 'ask'] : ['interest', 'ask'];
    },
    canAdd() {
      return this.files.length < MAX_FILES;
    },
  },
  watch: {
    campaignId: {
      immediate: true,
      handler(id) {
        if (id) this.load();
      },
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`CAMPAIGNS2.FILES.${key}`, params);
    },
    async load() {
      try {
        const { data } = await Motor2CampaignsAPI.files(this.campaignId);
        this.files = data.files || [];
      } catch (e) {
        this.files = [];
      }
    },
    async onPick(event) {
      const picked = Array.from(event.target.files || []);
      event.target.value = '';
      if (!picked.length) return;
      const bad = picked.find(
        f => f.type.startsWith('image/') && !IMAGE_TYPES.includes(f.type)
      );
      if (bad) {
        useAlert(this.t('IMAGE_TYPE', { name: bad.name }));
        return;
      }
      this.uploading = true;
      try {
        if (!(await this.save())) return;
        // eslint-disable-next-line no-restricted-syntax
        for (const file of picked.slice(0, MAX_FILES - this.files.length)) {
          // Uno por uno: cada uno trae su error (tamaño o tipo que WhatsApp no acepta).
          // eslint-disable-next-line no-await-in-loop
          const { data } = await Motor2CampaignsAPI.uploadFile(
            this.campaignId,
            file
          );
          this.files.push(data);
        }
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('UPLOAD_ERROR'));
      } finally {
        this.uploading = false;
      }
    },
    has(file, key) {
      return !!file.rules?.[key];
    },
    hasTouch(file, n) {
      return (file.rules?.attempts || []).map(Number).includes(n);
    },
    toggleTouch(file, n) {
      const list = (file.rules?.attempts || []).map(Number);
      const attempts = list.includes(n)
        ? list.filter(x => x !== n)
        : [...list, n].sort();
      this.update(file, { attempts });
    },
    toggle(file, key) {
      this.update(file, { [key]: !this.has(file, key) });
    },
    setAbout(file, about) {
      if ((file.rules?.about || '') === about.trim()) return;
      this.update(file, { about: about.trim() });
    },
    async update(file, change) {
      const rules = { ...file.rules, ...change };
      try {
        const { data } = await Motor2CampaignsAPI.updateFile(
          this.campaignId,
          file.id,
          rules
        );
        Object.assign(file, data);
      } catch (e) {
        useAlert(this.t('UPDATE_ERROR'));
      }
    },
    async remove(file) {
      try {
        await Motor2CampaignsAPI.removeFile(this.campaignId, file.id);
        this.files = this.files.filter(f => f.id !== file.id);
      } catch (e) {
        useAlert(this.t('UPDATE_ERROR'));
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <span class="field-label">{{ t('TITLE') }}</span>
    <p class="m-0 text-xs text-slate-500">{{ t('HINT') }}</p>
    <div
      v-for="file in files"
      :key="file.id"
      class="flex flex-col gap-1 p-2 border rounded-md border-slate-100 dark:border-slate-700"
    >
      <div class="flex items-start gap-2">
        <img
          v-if="file.image && file.url"
          :src="file.url"
          :alt="file.name"
          class="object-cover w-12 h-12 rounded shrink-0"
        />
        <div class="flex-1 min-w-0">
          <p class="m-0 text-sm font-medium truncate">{{ file.filename }}</p>
          <input
            type="text"
            class="!mb-0 text-xs"
            maxlength="300"
            :value="file.rules.about"
            :placeholder="t('ABOUT_PLACEHOLDER')"
            @change="setAbout(file, $event.target.value)"
          />
          <p
            v-if="!file.rules.about"
            class="m-0 mt-0.5 text-[11px] text-amber-700"
          >
            {{ t('ABOUT_MISSING') }}
          </p>
        </div>
        <button
          type="button"
          class="text-slate-400 hover:text-red-600"
          :aria-label="t('REMOVE')"
          @click="remove(file)"
        >
          <fluent-icon icon="dismiss" size="14" />
        </button>
      </div>
      <div class="flex flex-wrap gap-x-3 gap-y-1 text-xs">
        <label
          v-for="n in touches"
          :key="`t${n}`"
          class="flex items-center gap-1"
        >
          <input
            type="checkbox"
            class="!m-0"
            :checked="hasTouch(file, n)"
            @change="toggleTouch(file, n)"
          />
          {{ t('TOUCH', { n }) }}
        </label>
        <label v-for="key in flags" :key="key" class="flex items-center gap-1">
          <input
            type="checkbox"
            class="!m-0"
            :checked="has(file, key)"
            @change="toggle(file, key)"
          />
          {{ t(`WHEN.${key}`) }}
        </label>
      </div>
    </div>
    <label
      v-if="canAdd"
      class="self-start text-xs cursor-pointer text-woot-600 hover:underline"
    >
      {{ uploading ? t('UPLOADING') : t('ADD') }}
      <input
        type="file"
        multiple
        class="hidden"
        accept="image/jpeg,image/png,application/pdf,video/mp4"
        :disabled="uploading"
        @change="onPick"
      />
    </label>
    <p class="m-0 text-[11px] text-slate-500">{{ t('LIMITS') }}</p>
  </div>
</template>

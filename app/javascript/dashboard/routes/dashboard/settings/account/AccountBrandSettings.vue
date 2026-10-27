<!--
  feat/apariencia B1 — MARCA DE LA EMPRESA (Ajustes › Configuración de cuenta)
  El logo reemplaza la burbuja de arriba a la izquierda del menú y el color es el
  tema de todos los agentes («De la empresa» en su Apariencia), salvo quien elija
  otro. Se guarda al momento (sin el botón de la página).
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import AccountBrandAPI from 'dashboard/api/accountBrand';
import AppearanceCard from '../profile/AppearanceCard.vue';
import { COLOR_TINTS } from 'dashboard/helper/themeHelper';

// Las mismas muestras que en Perfil › Apariencia.
const TINT_SWATCHES = {
  default: ['#0090FF', '#5EB0EF', '#E6E8EB', '#26292B'],
  calido: ['#F76808', '#FA934E', '#E9E9E6', '#282826'],
  bosque: ['#46A758', '#65BA75', '#E6E9E8', '#252A27'],
  indigo: ['#3E63DD', '#8DA4EF', '#E9E8EA', '#28282C'],
  sepia: ['#846358', '#BFA094', '#EDE9E3', '#2E271E'],
  contraste: ['#006ADC', '#0090FF', '#F3F3F3', '#1C1C1C'],
  violeta: ['#6E56CF', '#AA99EC', '#E9E8EA', '#28282C'],
  turquesa: ['#12A594', '#53B9AB', '#E6E9E8', '#252A27'],
  rosa: ['#D6409F', '#E38EC3', '#E9E8EA', '#28282C'],
  grafito: ['#707070', '#C7C7C7', '#E6E9E6', '#262925'],
};

export default {
  name: 'AccountBrandSettings',
  components: { AppearanceCard },
  data() {
    return { saving: false };
  },
  computed: {
    ...mapGetters({ accountId: 'getCurrentAccountId' }),
    account() {
      return this.$store.getters['accounts/getAccount'](this.accountId) || {};
    },
    brand() {
      return this.account.brand || { tint: 'default', logo_url: null };
    },
    tints() {
      return COLOR_TINTS.map(key => ({
        key,
        title: this.$t(
          `PROFILE_SETTINGS.FORM.APPEARANCE.TINTS.${key.toUpperCase()}`
        ),
        swatches: TINT_SWATCHES[key],
      }));
    },
  },
  methods: {
    async save(payload) {
      this.saving = true;
      try {
        await AccountBrandAPI.update(payload);
        await this.$store.dispatch('accounts/get');
        useAlert(this.$t('GENERAL_SETTINGS.BRAND.SAVED'));
      } catch (error) {
        useAlert(
          (error.response &&
            error.response.data &&
            error.response.data.error) ||
            this.$t('GENERAL_SETTINGS.BRAND.ERROR')
        );
      } finally {
        this.saving = false;
      }
    },
    chooseTint(key) {
      if (key === this.brand.tint) return;
      const data = new FormData();
      data.append('tint', key);
      this.save(data);
    },
    onLogo(event) {
      const [file] = event.target.files || [];
      event.target.value = '';
      if (!file) return;
      const data = new FormData();
      data.append('logo', file);
      this.save(data);
    },
    async removeLogo() {
      this.saving = true;
      try {
        await AccountBrandAPI.removeLogo();
        await this.$store.dispatch('accounts/get');
      } finally {
        this.saving = false;
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-row p-4 border-b border-slate-25 dark:border-slate-800">
    <div class="flex-grow-0 flex-shrink-0 flex-[25%] min-w-0 py-4 pr-6 pl-0">
      <h4 class="text-lg font-medium text-black-900 dark:text-slate-200">
        {{ $t('GENERAL_SETTINGS.BRAND.TITLE') }}
      </h4>
      <p>{{ $t('GENERAL_SETTINGS.BRAND.NOTE') }}</p>
    </div>
    <div class="p-4 flex-grow-0 flex-shrink-0 flex-[50%] flex flex-col gap-6">
      <div class="flex flex-col gap-2">
        <span class="text-sm font-medium text-slate-800 dark:text-slate-100">
          {{ $t('GENERAL_SETTINGS.BRAND.LOGO') }}
        </span>
        <div class="flex items-center gap-4">
          <div
            class="flex items-center justify-center w-16 h-16 overflow-hidden border border-dashed rounded-xl border-slate-200 dark:border-slate-600 bg-slate-25 dark:bg-slate-800"
          >
            <img
              v-if="brand.logo_url"
              :src="brand.logo_url"
              :alt="account.name"
              class="object-contain w-full h-full p-1"
            />
            <fluent-icon v-else icon="image" size="24" class="text-slate-400" />
          </div>
          <div class="flex flex-col gap-1">
            <label
              class="!mb-0 button smooth small cursor-pointer w-fit"
              :class="{ disabled: saving }"
            >
              {{
                brand.logo_url
                  ? $t('GENERAL_SETTINGS.BRAND.CHANGE_LOGO')
                  : $t('GENERAL_SETTINGS.BRAND.UPLOAD_LOGO')
              }}
              <input
                type="file"
                class="hidden"
                accept="image/png,image/jpeg,image/svg+xml,image/webp"
                :disabled="saving"
                @change="onLogo"
              />
            </label>
            <button
              v-if="brand.logo_url"
              type="button"
              class="p-0 text-xs text-left text-red-600 bg-transparent border-0 w-fit"
              :disabled="saving"
              @click="removeLogo"
            >
              {{ $t('GENERAL_SETTINGS.BRAND.REMOVE_LOGO') }}
            </button>
            <span class="text-xs text-slate-500 dark:text-slate-400">
              {{ $t('GENERAL_SETTINGS.BRAND.LOGO_HELP') }}
            </span>
          </div>
        </div>
      </div>
      <div class="flex flex-col gap-2">
        <span class="text-sm font-medium text-slate-800 dark:text-slate-100">
          {{ $t('GENERAL_SETTINGS.BRAND.COLOR') }}
        </span>
        <div class="grid w-full gap-3 sm:grid-cols-2 lg:grid-cols-3">
          <AppearanceCard
            v-for="tint in tints"
            :key="tint.key"
            name="account-brand-tint"
            :title="tint.title"
            :swatches="tint.swatches"
            :active="brand.tint === tint.key"
            @click="chooseTint(tint.key)"
          />
        </div>
      </div>
    </div>
  </div>
</template>

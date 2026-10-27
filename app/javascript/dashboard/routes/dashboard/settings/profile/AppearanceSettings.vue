<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import { LocalStorage } from 'shared/helpers/localStorage';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import {
  setColorTheme,
  setColorTint,
  getColorTint,
  announceAppearanceChange,
  COMPANY_TINT,
  TINT_CHOICES,
} from 'dashboard/helper/themeHelper';
import { useStoreGetters } from 'dashboard/composables/store';
import AppearanceCard from './AppearanceCard.vue';

const { t } = useI18n();
const getters = useStoreGetters();

// feat/apariencia B1: el color que eligió la empresa (Ajustes › Configuración de cuenta).
const companyTint = computed(() => {
  const account = getters['accounts/getAccount'].value(
    getters.getCurrentAccountId.value
  );
  return (account && account.brand && account.brand.tint) || 'default';
});

const MODE_SWATCHES = {
  light: ['#FFFFFF', '#E6E8EB', '#C1C8CD', '#0090FF'],
  dark: ['#151718', '#26292B', '#4C5155', '#0090FF'],
  auto: ['#FFFFFF', '#E6E8EB', '#26292B', '#151718'],
};

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

const selectedMode = ref(
  LocalStorage.get(LOCAL_STORAGE_KEYS.COLOR_SCHEME) || 'auto'
);
const selectedTint = ref(getColorTint());

const modes = computed(() =>
  Object.keys(MODE_SWATCHES).map(key => ({
    key,
    title: t(`PROFILE_SETTINGS.FORM.APPEARANCE.MODES.${key.toUpperCase()}`),
    swatches: MODE_SWATCHES[key],
  }))
);

const tints = computed(() =>
  TINT_CHOICES.map(key => {
    if (key === COMPANY_TINT) {
      return {
        key,
        title: t('PROFILE_SETTINGS.FORM.APPEARANCE.TINTS.EMPRESA', {
          name: t(
            `PROFILE_SETTINGS.FORM.APPEARANCE.TINTS.${companyTint.value.toUpperCase()}`
          ),
        }),
        swatches: TINT_SWATCHES[companyTint.value] || TINT_SWATCHES.default,
      };
    }
    return {
      key,
      title: t(`PROFILE_SETTINGS.FORM.APPEARANCE.TINTS.${key.toUpperCase()}`),
      swatches: TINT_SWATCHES[key],
    };
  })
);

const selectMode = key => {
  selectedMode.value = key;
  LocalStorage.set(LOCAL_STORAGE_KEYS.COLOR_SCHEME, key);
  setColorTheme(window.matchMedia('(prefers-color-scheme: dark)').matches);
  announceAppearanceChange();
};

const selectTint = key => {
  selectedTint.value = key;
  setColorTint(key);
  announceAppearanceChange();
};
</script>

<template>
  <div class="flex flex-col w-full gap-6">
    <!-- feat/apariencia: vista previa en vivo (usa las mismas clases que el resto del
         tablero, así que cambia al momento con el modo y el tema elegidos). -->
    <div class="flex flex-col gap-3">
      <span class="text-sm font-medium text-ash-900">
        {{ $t('PROFILE_SETTINGS.FORM.APPEARANCE.PREVIEW.TITLE') }}
      </span>
      <div
        class="flex overflow-hidden border border-solid rounded-xl border-slate-100 dark:border-slate-700 bg-slate-25 dark:bg-slate-800"
      >
        <ul
          class="flex flex-col w-40 gap-1 p-3 m-0 list-none bg-white border-r border-solid dark:bg-slate-900 border-slate-50 dark:border-slate-700"
        >
          <li
            class="px-2 py-1.5 text-xs font-medium rounded-md bg-woot-50 dark:bg-woot-800 text-woot-600 dark:text-woot-100"
          >
            {{ $t('PROFILE_SETTINGS.FORM.APPEARANCE.PREVIEW.MENU_1') }}
          </li>
          <li class="px-2 py-1.5 text-xs text-slate-600 dark:text-slate-300">
            {{ $t('PROFILE_SETTINGS.FORM.APPEARANCE.PREVIEW.MENU_2') }}
          </li>
          <li class="px-2 py-1.5 text-xs text-slate-600 dark:text-slate-300">
            {{ $t('PROFILE_SETTINGS.FORM.APPEARANCE.PREVIEW.MENU_3') }}
          </li>
        </ul>
        <div class="flex flex-col flex-1 gap-3 p-4">
          <p
            class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
          >
            {{ $t('PROFILE_SETTINGS.FORM.APPEARANCE.PREVIEW.HEADING') }}
          </p>
          <div class="flex flex-wrap items-center gap-3 text-xs">
            <span
              class="font-medium underline text-woot-600 dark:text-woot-300"
            >
              {{ $t('PROFILE_SETTINGS.FORM.APPEARANCE.PREVIEW.LINK') }}
            </span>
            <span
              class="px-2 py-0.5 rounded-full bg-woot-75 dark:bg-woot-800 text-woot-700 dark:text-woot-100"
            >
              {{ $t('PROFILE_SETTINGS.FORM.APPEARANCE.PREVIEW.CHIP') }}
            </span>
          </div>
          <div class="flex flex-wrap gap-2">
            <span
              class="px-3 py-1.5 text-xs font-medium text-white rounded-md bg-woot-500"
            >
              {{ $t('PROFILE_SETTINGS.FORM.APPEARANCE.PREVIEW.PRIMARY') }}
            </span>
            <span
              class="px-3 py-1.5 text-xs font-medium rounded-md bg-primary-75 text-primary-700 dark:bg-primary-200 dark:text-primary-800"
            >
              {{ $t('PROFILE_SETTINGS.FORM.APPEARANCE.PREVIEW.SECONDARY') }}
            </span>
          </div>
        </div>
      </div>
    </div>
    <div class="flex flex-col gap-3">
      <span class="text-sm font-medium text-ash-900">
        {{ $t('PROFILE_SETTINGS.FORM.APPEARANCE.MODE_LABEL') }}
      </span>
      <div class="grid w-full gap-4 sm:grid-cols-3">
        <AppearanceCard
          v-for="mode in modes"
          :key="mode.key"
          name="appearance-mode"
          :title="mode.title"
          :swatches="mode.swatches"
          :active="selectedMode === mode.key"
          @click="selectMode(mode.key)"
        />
      </div>
    </div>
    <div class="flex flex-col gap-3">
      <span class="text-sm font-medium text-ash-900">
        {{ $t('PROFILE_SETTINGS.FORM.APPEARANCE.TINT_LABEL') }}
      </span>
      <div class="grid w-full gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <AppearanceCard
          v-for="tint in tints"
          :key="tint.key"
          name="appearance-tint"
          :title="tint.title"
          :swatches="tint.swatches"
          :active="selectedTint === tint.key"
          @click="selectTint(tint.key)"
        />
      </div>
    </div>
  </div>
</template>

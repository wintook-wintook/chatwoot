<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import { LocalStorage } from 'shared/helpers/localStorage';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import {
  setColorTheme,
  setColorTint,
  getColorTint,
} from 'dashboard/helper/themeHelper';
import AppearanceCard from './AppearanceCard.vue';

const { t } = useI18n();

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
  Object.keys(TINT_SWATCHES).map(key => ({
    key,
    title: t(`PROFILE_SETTINGS.FORM.APPEARANCE.TINTS.${key.toUpperCase()}`),
    swatches: TINT_SWATCHES[key],
  }))
);

const selectMode = key => {
  selectedMode.value = key;
  LocalStorage.set(LOCAL_STORAGE_KEYS.COLOR_SCHEME, key);
  setColorTheme(window.matchMedia('(prefers-color-scheme: dark)').matches);
};

const selectTint = key => {
  selectedTint.value = key;
  setColorTint(key);
};
</script>

<template>
  <div class="flex flex-col w-full gap-6">
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
      <div class="grid w-full gap-4 sm:grid-cols-4">
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

import { computed } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import {
  ICON_APPEARANCE,
  ICON_LIGHT_MODE,
  ICON_DARK_MODE,
  ICON_SYSTEM_MODE,
} from 'dashboard/helper/commandbar/icons';
import { LocalStorage } from 'shared/helpers/localStorage';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import {
  setColorTheme,
  setColorTint,
  COLOR_TINTS,
} from 'dashboard/helper/themeHelper.js';

const getThemeOptions = t => [
  {
    key: 'light',
    label: t('COMMAND_BAR.COMMANDS.LIGHT_MODE'),
    icon: ICON_LIGHT_MODE,
  },
  {
    key: 'dark',
    label: t('COMMAND_BAR.COMMANDS.DARK_MODE'),
    icon: ICON_DARK_MODE,
  },
  {
    key: 'auto',
    label: t('COMMAND_BAR.COMMANDS.SYSTEM_MODE'),
    icon: ICON_SYSTEM_MODE,
  },
];

const getTintOptions = t =>
  COLOR_TINTS.map(tint => ({
    key: tint,
    label: t(`PROFILE_SETTINGS.FORM.APPEARANCE.TINTS.${tint.toUpperCase()}`),
    icon: ICON_APPEARANCE,
  }));

const setAppearance = theme => {
  LocalStorage.set(LOCAL_STORAGE_KEYS.COLOR_SCHEME, theme);
  const isOSOnDarkMode = window.matchMedia(
    '(prefers-color-scheme: dark)'
  ).matches;
  setColorTheme(isOSOnDarkMode);
};

export function useAppearanceHotKeys() {
  const { t } = useI18n();

  const themeOptions = computed(() => getThemeOptions(t));
  const tintOptions = computed(() => getTintOptions(t));

  const goToAppearanceHotKeys = computed(() => {
    const options = themeOptions.value.map(theme => ({
      id: theme.key,
      title: theme.label,
      parent: 'appearance_settings',
      section: t('COMMAND_BAR.SECTIONS.APPEARANCE'),
      icon: theme.icon,
      handler: () => {
        setAppearance(theme.key);
      },
    }));
    const tints = tintOptions.value.map(tint => ({
      id: `tint_${tint.key}`,
      title: tint.label,
      parent: 'appearance_tint',
      section: t('COMMAND_BAR.SECTIONS.APPEARANCE'),
      icon: tint.icon,
      handler: () => {
        setColorTint(tint.key);
      },
    }));

    return [
      {
        id: 'appearance_settings',
        title: t('COMMAND_BAR.COMMANDS.CHANGE_APPEARANCE'),
        section: t('COMMAND_BAR.SECTIONS.APPEARANCE'),
        icon: ICON_APPEARANCE,
        children: options.map(option => option.id),
      },
      ...options,
      {
        id: 'appearance_tint',
        title: t('COMMAND_BAR.COMMANDS.CHANGE_COLOR_THEME'),
        section: t('COMMAND_BAR.SECTIONS.APPEARANCE'),
        icon: ICON_APPEARANCE,
        children: tints.map(tint => tint.id),
      },
      ...tints,
    ];
  });

  return {
    goToAppearanceHotKeys,
  };
}

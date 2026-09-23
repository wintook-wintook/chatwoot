import { LocalStorage } from 'shared/helpers/localStorage';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';

// Temas de color. `default` no lleva atributo en el body: deja las escalas
// `woot` y `slate` en los valores por omisión de tailwind.config.js.
export const COLOR_TINTS = [
  'default',
  'calido',
  'bosque',
  'indigo',
  'sepia',
  'contraste',
  'violeta',
  'turquesa',
  'rosa',
  'grafito',
];

export const setColorTheme = isOSOnDarkMode => {
  const selectedColorScheme =
    LocalStorage.get(LOCAL_STORAGE_KEYS.COLOR_SCHEME) || 'auto';
  if (
    (selectedColorScheme === 'auto' && isOSOnDarkMode) ||
    selectedColorScheme === 'dark'
  ) {
    document.body.classList.add('dark');
    document.documentElement.setAttribute('style', 'color-scheme: dark;');
  } else {
    document.body.classList.remove('dark');
    document.documentElement.setAttribute('style', 'color-scheme: light;');
  }
};

export const getColorTint = () => {
  const tint = LocalStorage.get(LOCAL_STORAGE_KEYS.COLOR_TINT);
  return COLOR_TINTS.includes(tint) ? tint : 'default';
};

export const applyColorTint = () => {
  const tint = getColorTint();
  if (tint === 'default') {
    document.body.removeAttribute('data-tema');
  } else {
    document.body.setAttribute('data-tema', tint);
  }
};

export const setColorTint = tint => {
  const selectedTint = COLOR_TINTS.includes(tint) ? tint : 'default';
  LocalStorage.set(LOCAL_STORAGE_KEYS.COLOR_TINT, selectedTint);
  applyColorTint();
};

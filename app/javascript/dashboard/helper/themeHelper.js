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

// feat/apariencia B1 — «De la empresa»: el color que eligió el administrador en
// Ajustes › Configuración de cuenta. Es la opción por omisión de todos los agentes;
// quien elige otro tema se queda con el suyo.
export const COMPANY_TINT = 'empresa';
export const TINT_CHOICES = [COMPANY_TINT, ...COLOR_TINTS];
const COMPANY_TINT_STORAGE_KEY = 'company_tint';

export const getCompanyTint = () => {
  const tint = LocalStorage.get(COMPANY_TINT_STORAGE_KEY);
  return COLOR_TINTS.includes(tint) ? tint : 'default';
};

// Lo que eligió el agente (puede ser «empresa»); sin elección, el de la empresa.
export const getColorTint = () => {
  const tint = LocalStorage.get(LOCAL_STORAGE_KEYS.COLOR_TINT);
  return TINT_CHOICES.includes(tint) ? tint : COMPANY_TINT;
};

// El tema que se pinta: «empresa» se vuelve el color de la empresa.
export const resolvedColorTint = () => {
  const tint = getColorTint();
  return tint === COMPANY_TINT ? getCompanyTint() : tint;
};

export const applyColorTint = () => {
  const tint = resolvedColorTint();
  if (tint === 'default') {
    document.body.removeAttribute('data-tema');
  } else {
    document.body.setAttribute('data-tema', tint);
  }
};

export const setColorTint = tint => {
  const selectedTint = TINT_CHOICES.includes(tint) ? tint : COMPANY_TINT;
  LocalStorage.set(LOCAL_STORAGE_KEYS.COLOR_TINT, selectedTint);
  applyColorTint();
};

// feat/apariencia — el modo y el tema también se guardan en el usuario (ui_settings),
// para que sigan al agente en cualquier navegador o dispositivo. El navegador sigue
// siendo la copia rápida (se aplica antes de que cargue el usuario).
export const COLOR_SCHEMES = ['light', 'dark', 'auto'];
export const APPEARANCE_EVENT = 'woot:appearance-changed';
export const UI_SETTINGS_KEYS = {
  mode: 'appearance_mode',
  tint: 'appearance_tint',
};

// Avisa que el agente cambió la apariencia; App.vue lo guarda en su usuario.
export const announceAppearanceChange = () => {
  window.dispatchEvent(
    new CustomEvent(APPEARANCE_EVENT, {
      detail: {
        [UI_SETTINGS_KEYS.mode]:
          LocalStorage.get(LOCAL_STORAGE_KEYS.COLOR_SCHEME) || 'auto',
        [UI_SETTINGS_KEYS.tint]: getColorTint(),
      },
    })
  );
};

// Al cargar el usuario: si trae una apariencia guardada distinta de la del navegador,
// gana la del usuario.
export const syncAppearanceFromUser = (uiSettings = {}) => {
  const mode = uiSettings[UI_SETTINGS_KEYS.mode];
  const tint = uiSettings[UI_SETTINGS_KEYS.tint];
  if (COLOR_SCHEMES.includes(mode)) {
    LocalStorage.set(LOCAL_STORAGE_KEYS.COLOR_SCHEME, mode);
  }
  if (TINT_CHOICES.includes(tint)) {
    LocalStorage.set(LOCAL_STORAGE_KEYS.COLOR_TINT, tint);
  }
  setColorTheme(window.matchMedia('(prefers-color-scheme: dark)').matches);
  applyColorTint();
};

// La cuenta trae su color (account.brand.tint): se guarda y se vuelve a pintar.
export const setCompanyTint = tint => {
  LocalStorage.set(
    COMPANY_TINT_STORAGE_KEY,
    COLOR_TINTS.includes(tint) ? tint : 'default'
  );
  applyColorTint();
};

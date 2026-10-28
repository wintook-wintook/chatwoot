import {
  setColorTheme,
  syncAppearanceFromUser,
  announceAppearanceChange,
  APPEARANCE_EVENT,
} from 'dashboard/helper/themeHelper.js';
import { LocalStorage } from 'shared/helpers/localStorage';

vi.mock('shared/helpers/localStorage');

describe('setColorTheme', () => {
  it('should set body class to dark if selectedColorScheme is dark', () => {
    LocalStorage.get.mockReturnValue('dark');
    setColorTheme(true);
    expect(document.body.classList.contains('dark')).toBe(true);
  });

  it('should set body class to dark if selectedColorScheme is auto and isOSOnDarkMode is true', () => {
    LocalStorage.get.mockReturnValue('auto');
    setColorTheme(true);
    expect(document.body.classList.contains('dark')).toBe(true);
  });

  it('should not set body class to dark if selectedColorScheme is auto and isOSOnDarkMode is false', () => {
    LocalStorage.get.mockReturnValue('auto');
    setColorTheme(false);
    expect(document.body.classList.contains('dark')).toBe(false);
  });

  it('should not set body class to dark if selectedColorScheme is light', () => {
    LocalStorage.get.mockReturnValue('light');
    setColorTheme(true);
    expect(document.body.classList.contains('dark')).toBe(false);
  });

  it('should not set body class to dark if selectedColorScheme is undefined', () => {
    LocalStorage.get.mockReturnValue(undefined);
    setColorTheme(true);
    expect(document.body.classList.contains('dark')).toBe(true);
  });

  it('should set documentElement style to dark if selectedColorScheme is dark', () => {
    LocalStorage.get.mockReturnValue('dark');
    setColorTheme(true);
    expect(document.documentElement.getAttribute('style')).toBe(
      'color-scheme: dark;'
    );
  });

  it('should set documentElement style to dark if selectedColorScheme is auto and isOSOnDarkMode is true', () => {
    LocalStorage.get.mockReturnValue('auto');
    setColorTheme(true);
    expect(document.documentElement.getAttribute('style')).toBe(
      'color-scheme: dark;'
    );
  });

  it('should set documentElement style to light if selectedColorScheme is auto and isOSOnDarkMode is false', () => {
    LocalStorage.get.mockReturnValue('auto');
    setColorTheme(false);
    expect(document.documentElement.getAttribute('style')).toBe(
      'color-scheme: light;'
    );
  });

  it('should set documentElement style to light if selectedColorScheme is light', () => {
    LocalStorage.get.mockReturnValue('light');
    setColorTheme(true);
    expect(document.documentElement.getAttribute('style')).toBe(
      'color-scheme: light;'
    );
  });

  it('should set documentElement style to light if selectedColorScheme is undefined', () => {
    LocalStorage.get.mockReturnValue(undefined);
    setColorTheme(true);
    expect(document.documentElement.getAttribute('style')).toBe(
      'color-scheme: dark;'
    );
  });
});

// feat/apariencia — la apariencia también vive en el usuario.
describe('apariencia guardada en el usuario', () => {
  beforeEach(() => {
    window.matchMedia = vi.fn().mockReturnValue({ matches: false });
    LocalStorage.set.mockClear();
  });

  it('gana la del usuario al cargar', () => {
    LocalStorage.get.mockImplementation(key =>
      key === 'color_tint' ? 'bosque' : 'dark'
    );
    syncAppearanceFromUser({
      appearance_mode: 'dark',
      appearance_tint: 'bosque',
    });
    expect(LocalStorage.set).toHaveBeenCalledWith('color_scheme', 'dark');
    expect(LocalStorage.set).toHaveBeenCalledWith('color_tint', 'bosque');
    expect(document.body.getAttribute('data-tema')).toBe('bosque');
  });

  it('ignora valores que no existen', () => {
    syncAppearanceFromUser({ appearance_mode: 'neon', appearance_tint: 'x' });
    expect(LocalStorage.set).not.toHaveBeenCalled();
  });

  it('avisa el cambio con el modo y el tema actuales', () => {
    LocalStorage.get.mockImplementation(key =>
      key === 'color_tint' ? 'rosa' : 'light'
    );
    const listener = vi.fn();
    window.addEventListener(APPEARANCE_EVENT, listener);
    announceAppearanceChange();
    window.removeEventListener(APPEARANCE_EVENT, listener);
    expect(listener.mock.calls[0][0].detail).toEqual({
      appearance_mode: 'light',
      appearance_tint: 'rosa',
    });
  });
});

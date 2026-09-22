import { useAppearanceHotKeys } from '../useAppearanceHotKeys';
import { useI18n } from 'dashboard/composables/useI18n';
import { LocalStorage } from 'shared/helpers/localStorage';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import { setColorTheme, setColorTint } from 'dashboard/helper/themeHelper.js';

vi.mock('dashboard/composables/useI18n');
vi.mock('shared/helpers/localStorage');
vi.mock('dashboard/helper/themeHelper.js', async importOriginal => {
  const original = await importOriginal();
  return {
    ...original,
    setColorTheme: vi.fn(),
    setColorTint: vi.fn(),
  };
});

describe('useAppearanceHotKeys', () => {
  beforeEach(() => {
    useI18n.mockReturnValue({
      t: vi.fn(key => key),
    });

    window.matchMedia = vi.fn().mockReturnValue({ matches: false });
  });

  it('should return goToAppearanceHotKeys computed property', () => {
    const { goToAppearanceHotKeys } = useAppearanceHotKeys();
    expect(goToAppearanceHotKeys.value).toBeDefined();
  });

  it('should have the correct number of appearance options', () => {
    const { goToAppearanceHotKeys } = useAppearanceHotKeys();
    // 1 parent + 3 mode options, 1 parent + 6 color theme options
    expect(goToAppearanceHotKeys.value.length).toBe(11);
  });

  it('should have the correct parent option', () => {
    const { goToAppearanceHotKeys } = useAppearanceHotKeys();
    const parentOption = goToAppearanceHotKeys.value.find(
      option => option.id === 'appearance_settings'
    );
    expect(parentOption).toBeDefined();
    // los tres modos más la entrada que abre los temas de color
    expect(parentOption.children).toEqual([
      'light',
      'dark',
      'auto',
      'appearance_tint',
    ]);
  });

  it('should have the correct theme options', () => {
    const { goToAppearanceHotKeys } = useAppearanceHotKeys();
    const themeOptions = goToAppearanceHotKeys.value.filter(
      option => option.parent === 'appearance_settings'
    );
    expect(themeOptions.map(option => option.id)).toEqual([
      'light',
      'dark',
      'auto',
      'appearance_tint',
    ]);
  });

  it('should have the correct color theme options', () => {
    const { goToAppearanceHotKeys } = useAppearanceHotKeys();
    const parentOption = goToAppearanceHotKeys.value.find(
      option => option.id === 'appearance_tint'
    );
    expect(parentOption).toBeDefined();
    // cuelga de Cambiar apariencia, no del primer nivel
    expect(parentOption.parent).toBe('appearance_settings');
    expect(parentOption.children).toEqual([
      'tint_default',
      'tint_calido',
      'tint_bosque',
      'tint_indigo',
      'tint_sepia',
      'tint_contraste',
    ]);
  });

  it('should call setColorTint when a color theme is selected', () => {
    const { goToAppearanceHotKeys } = useAppearanceHotKeys();
    const tintOption = goToAppearanceHotKeys.value.find(
      option => option.id === 'tint_bosque'
    );

    tintOption.handler();

    expect(setColorTint).toHaveBeenCalledWith('bosque');
  });

  it('should call setAppearance when a theme option is selected', () => {
    const { goToAppearanceHotKeys } = useAppearanceHotKeys();
    const lightThemeOption = goToAppearanceHotKeys.value.find(
      option => option.id === 'light'
    );

    lightThemeOption.handler();

    expect(LocalStorage.set).toHaveBeenCalledWith(
      LOCAL_STORAGE_KEYS.COLOR_SCHEME,
      'light'
    );
    expect(setColorTheme).toHaveBeenCalledWith(false);
  });

  it('should handle system dark mode preference', () => {
    window.matchMedia = vi.fn().mockReturnValue({ matches: true });

    const { goToAppearanceHotKeys } = useAppearanceHotKeys();
    const autoThemeOption = goToAppearanceHotKeys.value.find(
      option => option.id === 'auto'
    );

    autoThemeOption.handler();

    expect(LocalStorage.set).toHaveBeenCalledWith(
      LOCAL_STORAGE_KEYS.COLOR_SCHEME,
      'auto'
    );
    expect(setColorTheme).toHaveBeenCalledWith(true);
  });
});

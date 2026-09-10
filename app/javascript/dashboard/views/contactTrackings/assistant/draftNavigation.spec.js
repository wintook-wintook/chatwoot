import { findRouteLine, lineRange } from './draftNavigation';

// proyecto@asistente_agentes_ia — el informe como índice
//
// Lo que sostiene este archivo es el límite del nombre de rama. Sin él, tocar
// "soporte" en el informe salta a la línea de "sop" y nadie lo nota: las dos son
// líneas @ruta plausibles y el editor simplemente selecciona la equivocada.
describe('draftNavigation', () => {
  const draft = [
    '[ROL] Sos el asistente de la empresa.', // 1
    '@ruta(sop #sop: consultas cortas): -', // 2
    '  @ruta(soporte #soporte: no puedo entrar): @buscar_articulo', // 3
    '@ruta(comercial: precios): @buscar_predefinidas', // 4
    '@RUTA(ADMIN #admin: facturas): -', // 5
    '@ruta_por_defecto: soporte', // 6
  ].join('\n');

  describe('findRouteLine', () => {
    it('encuentra la rama por su nombre', () => {
      expect(findRouteLine(draft, 'sop')).toBe(2);
      expect(findRouteLine(draft, 'comercial')).toBe(4);
    });

    // La regresión que justifica el spec.
    it('no confunde una rama con otra que la tiene de prefijo', () => {
      expect(findRouteLine(draft, 'soporte')).toBe(3);
    });

    it('encuentra una rama indentada', () => {
      expect(findRouteLine(draft, 'soporte')).toBe(3);
    });

    // RouteMap parsea @ruta sin distinguir mayúsculas (LINE_RE lleva /i), así que
    // el índice tampoco puede distinguirlas.
    it('ignora mayúsculas y minúsculas, igual que el parser del motor', () => {
      expect(findRouteLine(draft, 'admin')).toBe(5);
    });

    it('devuelve null cuando la rama no está en el texto', () => {
      expect(findRouteLine(draft, 'inexistente')).toBeNull();
    });

    it('no se cae con un borrador vacío ni sin nombre', () => {
      expect(findRouteLine('', 'soporte')).toBeNull();
      expect(findRouteLine(draft, '')).toBeNull();
      expect(findRouteLine(undefined, 'soporte')).toBeNull();
    });
  });

  describe('lineRange', () => {
    it('devuelve la línea entera, para poder seleccionarla', () => {
      const [start, end] = lineRange(draft, 3);

      expect(draft.slice(start, end)).toBe(
        '  @ruta(soporte #soporte: no puedo entrar): @buscar_articulo'
      );
    });

    it('la primera línea arranca en cero', () => {
      expect(lineRange(draft, 1)[0]).toBe(0);
    });

    it('devuelve null fuera de rango', () => {
      expect(lineRange(draft, 0)).toBeNull();
      expect(lineRange(draft, 99)).toBeNull();
      expect(lineRange(draft, null)).toBeNull();
    });

    // El hallazgo del comprobador trae la línea; el índice tiene que llevar
    // exactamente ahí.
    it('coincide con el número de línea que informa el comprobador', () => {
      const [start, end] = lineRange(draft, findRouteLine(draft, 'comercial'));

      expect(draft.slice(start, end)).toBe(
        '@ruta(comercial: precios): @buscar_predefinidas'
      );
    });
  });
});

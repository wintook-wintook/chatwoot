import { shallowMount } from '@vue/test-utils';
import AttachmentUploader from '../AttachmentUploader.vue';
import AiAgentAttachmentsAPI from 'dashboard/api/aiAgentAttachments';
import {
  nameFromFile,
  uniqueName,
  isValidName,
  isTaken,
} from '../attachmentNames';

vi.mock('dashboard/api/aiAgentAttachments', () => ({
  default: { upload: vi.fn() },
}));

const archivo = (nombre, size = 100) => ({ name: nombre, size });

const montar = (existingNames = []) =>
  shallowMount(AttachmentUploader, {
    propsData: { templateId: 7, existingNames },
    mocks: {
      $t: (clave, params) => (params ? `${clave}:${params.count}` : clave),
    },
    directives: { tooltip: {} },
  });

const esperar = () =>
  new Promise(resolve => {
    setTimeout(resolve);
  });

describe('attachmentNames', () => {
  it('sugiere el nombre desde el archivo, sin acentos ni espacios', () => {
    expect(nameFromFile('Catálogo 2026.pdf')).toBe('catalogo-2026');
    expect(nameFromFile('Lista_precios.v2.xlsx')).toBe('lista_precios-v2');
    expect(nameFromFile('ñ.pdf')).toBe('n');
    expect(nameFromFile('¿?.pdf')).toBe('archivo');
  });

  it('agrega -2, -3 cuando el nombre ya existe (sin importar mayúsculas)', () => {
    expect(uniqueName('garantia', ['otro'])).toBe('garantia');
    expect(uniqueName('garantia', ['Garantia'])).toBe('garantia-2');
    expect(uniqueName('garantia', ['garantia', 'garantia-2'])).toBe(
      'garantia-3'
    );
    expect(uniqueName('a'.repeat(60), ['a'.repeat(60)])).toHaveLength(60);
  });

  it('valida el formato y los repetidos', () => {
    expect(isValidName('catalogo_2026-v1')).toBe(true);
    expect(isValidName('con espacio')).toBe(false);
    expect(isValidName('')).toBe(false);
    expect(isTaken('Catalogo', ['catalogo'], [])).toBe(true);
    expect(isTaken('catalogo', [], ['otro'])).toBe(false);
  });
});

describe('AttachmentUploader', () => {
  beforeEach(() => {
    AiAgentAttachmentsAPI.upload.mockReset();
  });

  it('agrega varios archivos con nombres sugeridos y sin repetir', () => {
    const wrapper = montar(['garantia']);
    wrapper.vm.addFiles([
      archivo('Garantía.pdf'),
      archivo('Catálogo.pdf'),
      archivo('catalogo.docx'),
    ]);
    expect(wrapper.vm.pending.map(p => p.name)).toEqual([
      'garantia-2',
      'catalogo',
      'catalogo-2',
    ]);
    expect(wrapper.vm.canUpload).toBe(true);
  });

  it('no deja subir si un nombre es inválido o se repite', () => {
    const wrapper = montar(['catalogo']);
    wrapper.vm.addFiles([archivo('a.pdf'), archivo('b.pdf')]);
    wrapper.vm.pending[0].name = 'con espacio';
    expect(wrapper.vm.canUpload).toBe(false);
    wrapper.vm.pending[0].name = 'catalogo';
    expect(wrapper.vm.problem(wrapper.vm.pending[0])).toBe(
      'TRACKING_TEMPLATES.FORM.ATTACHMENTS.DUPLICATE_NAME'
    );
    wrapper.vm.pending[0].name = 'nuevo';
    expect(wrapper.vm.canUpload).toBe(true);
  });

  it('sube uno por uno; si uno falla, los demás sí entran', async () => {
    AiAgentAttachmentsAPI.upload
      .mockResolvedValueOnce({ data: { id: 1, name: 'a' } })
      .mockRejectedValueOnce({
        response: { data: { errors: ['Archivo muy grande'] } },
      })
      .mockResolvedValueOnce({ data: { id: 3, name: 'c' } });
    const wrapper = montar();
    wrapper.vm.addFiles([archivo('a.pdf'), archivo('b.pdf'), archivo('c.pdf')]);

    await wrapper.vm.uploadAll();
    await esperar();

    expect(AiAgentAttachmentsAPI.upload).toHaveBeenCalledTimes(3);
    expect(AiAgentAttachmentsAPI.upload.mock.calls[0][0]).toBe(7);
    expect(wrapper.emitted('uploaded').map(e => e[0].id)).toEqual([1, 3]);
    expect(wrapper.vm.pending).toHaveLength(1);
    expect(wrapper.vm.pending[0].name).toBe('b');
    expect(wrapper.vm.pending[0].status).toBe('error');
    expect(wrapper.vm.pending[0].error).toBe('Archivo muy grande');

    // Reintentar: el mismo botón vuelve a mandar el que falló.
    AiAgentAttachmentsAPI.upload.mockResolvedValueOnce({
      data: { id: 2, name: 'b' },
    });
    await wrapper.vm.uploadAll();
    expect(wrapper.vm.pending).toHaveLength(0);
  });

  it('quita un archivo de la lista antes de subir', () => {
    const wrapper = montar();
    wrapper.vm.addFiles([archivo('a.pdf'), archivo('b.pdf')]);
    wrapper.vm.remove(wrapper.vm.pending[0]);
    expect(wrapper.vm.pending.map(p => p.name)).toEqual(['b']);
  });
});

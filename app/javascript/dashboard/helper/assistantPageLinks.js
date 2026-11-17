// Asistente (Dali) — las pantallas que menciona salen como liga. El servidor
// (Assistant::PageLinks) deja en el texto [[/app/accounts/1/ruta|Nombre]]; aquí se
// formatea el resto como siempre (MessageFormatter) y esas marcas se vuelven
// <a data-dali-path="…">. El clic lo atiende AssistantChat (navigate, sin recargar).
const LINK = /\[\[(\/app\/accounts\/\d+\/[^|\]\s]*)\|([^\]|]{1,80})\]\]/g;
const SLOT = i => `DALIPAGE${i}X`;

const escapeHtml = text =>
  text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');

export const renderWithPageLinks = (content, format) => {
  const links = [];
  const text = (content || '').replace(LINK, (_m, path, label) => {
    links.push({ path, label });
    return SLOT(links.length - 1);
  });
  let html = format(text);
  links.forEach(({ path, label }, i) => {
    const safePath = escapeHtml(path);
    html = html.replace(
      SLOT(i),
      `<a href="${safePath}" class="dali-page-link" data-dali-path="${safePath}">${escapeHtml(
        label
      )}</a>`
    );
  });
  return html;
};

// La ruta de la liga en la que se hizo clic, o null.
export const pageLinkFromEvent = event =>
  event?.target?.closest?.('a[data-dali-path]')?.dataset?.daliPath || null;

// proyecto@asistente_agentes_ia — LOS RECURSOS DEL MOTOR, COMO DOCUMENTO (.md)
// ============================================================================
// La pestaña Recursos, para llevársela (pedido del usuario, 23/09/2026): todo lo que
// el motor sabe hacer, cómo se escribe, qué necesita y con qué nombres exactos está
// en ESTA cuenta. Se arma en el navegador con lo mismo que dibuja la pestaña (el
// catálogo del backend y los textos del i18n): no pasa por la IA ni cuesta nada.
//
// `t` es la función de traducción (this.$t), para que el documento salga en el
// idioma de la cuenta.
// ============================================================================

const GROUPS = ['sources', 'actions', 'structure'];
const K = 'TRACKING_ASSISTANT_VIEW.';

const code = texto => `\`${texto}\``;

const cardMarkdown = (card, t) => {
  const key = card.key.toUpperCase();
  const lineas = [
    `### ${code(card.syntax)} — ${t(
      `${K}CATALOG_STATUS_${card.status.toUpperCase()}`
    )}`,
    '',
    `**${t(`${K}CATALOG_MD_WHAT`)}** ${t(`${K}CATALOG_${key}_WHAT`)}`,
    '',
    `**${t(`${K}CATALOG_NEEDS`)}** ${t(`${K}CATALOG_${key}_NEEDS`)}`,
  ];
  if (card.items.length) {
    lineas.push(
      '',
      `**${t(`${K}CATALOG_IN_ACCOUNT`)}** ${card.items.map(code).join(' · ')}`
    );
  }
  return lineas.join('\n');
};

export const engineCatalogMarkdown = (
  catalog,
  t,
  { accountName = '', date = new Date(), locale } = {}
) => {
  const fecha = date.toLocaleDateString(locale);
  const partes = [
    `# ${t(`${K}CATALOG_MD_TITLE`)}`,
    '',
    [accountName && `${t(`${K}CATALOG_MD_ACCOUNT`)}: ${accountName}`, fecha]
      .filter(Boolean)
      .join(' · '),
    '',
    t(`${K}CATALOG_MD_INTRO`),
    '',
    `## ${t(`${K}CATALOG_MD_EXAMPLE_TITLE`)}`,
    '',
    t(`${K}CATALOG_MD_EXAMPLE_HINT`),
    '',
    '```',
    t(`${K}CATALOG_MD_EXAMPLE`),
    '```',
  ];
  GROUPS.forEach(group => {
    const cards = catalog.filter(card => card.group === group);
    if (!cards.length) return;
    partes.push(
      '',
      `## ${t(`${K}CATALOG_GROUP_${group.toUpperCase()}`)}`,
      '',
      cards.map(card => cardMarkdown(card, t)).join('\n\n')
    );
  });
  return `${partes.join('\n')}\n`;
};

export const downloadMarkdown = (content, filename) => {
  const blob = new Blob([content], { type: 'text/markdown;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
};

# frozen_string_literal: true

# «Atención a clientes» — saber de qué empresa es quien escribe (el contacto ya lo crea Kontrolya solo):
#   - si ya está ligado a su organización (o se ligó por el dominio de su correo: Motor2::CustomerIdentity),
#     el agente ve lo que se sabe de él (Motor2::CustomerContext): su empresa, los sistemas que usa, sus
#     casos abiertos y sus contratos; así no pregunta lo que ya se sabe;
#   - si no, le pregunta UNA vez de qué empresa escribe (y su correo), ya que entendió qué necesita, y lo
#     guarda con identificar_empresa: si la empresa está en Organizaciones se liga; si no, se atiende igual
#     y queda una nota para el equipo («dice ser de X»). Antes de levantar un caso se pregunta sí o sí
#     (Motor2::Skills::SupportCatalog#case_blocker);
#   - el correo que da y ya es de otro contacto no se pisa: nota de «posible duplicado» (Unir contactos).
# Lo que dice él no está comprobado: sirve para ayudar, nunca para dar datos de la cuenta.
#
#   memoria: state['empresa'] = { 'nombre', 'encontrada' }, state['empresa_preguntada']
class Motor2::Skills::Identity < Motor2::Skills::Base
  ASKED = /\bempresa\b[^?]*\?|\?[^?]*\bempresa\b/i
  NOTE = '🤖 %<agent>s: %<text>s'

  def self.key = 'identity'

  def prepare(history)
    last_agent = Array(history)[0...-1].reverse.find { |m| m[:role].to_s == 'assistant' }&.dig(:content).to_s
    state['empresa_preguntada'] = true if last_agent.match?(ASKED)
  end

  def tools
    return [] if known?

    [fn('identificar_empresa', 'Guarda de qué empresa escribe el cliente (y su correo, si lo dio), en cuanto lo diga.',
        { empresa: STR, correo: STR }, %w[empresa])]
  end

  def instructions
    <<~TEXT.strip
      - Lo que sabes del cliente (SU EMPRESA, SISTEMAS QUE USA, SUS CASOS…) es para ayudarlo sin preguntarle lo que ya
        sabes. No le des datos de su cuenta (montos, facturas, saldos, casos de otras personas).
    TEXT
  end

  def memory
    lines = Motor2::CustomerContext.lines(contact)
    lines << "DIJO QUE ES DE: #{state.dig('empresa', 'nombre')}" if state['empresa'] && !contact&.organization
    lines << ask_line unless known?
    lines.compact.join("\n")
  end

  def call(_name, args)
    said = args['empresa'].to_s.squish.first(120)
    return { error: 'Falta la empresa.' } if said.blank?

    org = remember(said)
    save(org, said, args['correo'].to_s.strip) if contact && !test?
    return { ok: true, empresa: org.name, nota: 'Listo: sigue con lo que necesita.' } if org

    { ok: true, nota: 'Lo atiendes igual (el equipo lo revisa); no le digas que no lo encontraste.' }
  end

  # Ya se sabe de qué empresa es (o ya se le preguntó y la dijo).
  def known? = contact&.organization.present? || state['empresa'].present?

  # Antes de levantar un caso: aún no se sabe y no se le ha preguntado.
  def must_ask? = !known? && !state['empresa_preguntada']

  def labels
    return [] unless @saved

    [('empresa-no-encontrada' unless @saved[:org]), ('posible-duplicado' if @saved[:duplicate])].compact
  end

  private

  def contact = @turn.conversation&.contact

  def remember(said)
    org = Motor2::CustomerIdentity.find(config.account, said)
    state['empresa'] = { 'nombre' => org&.name || said, 'encontrada' => org.present? }
    trace.event(:empresa, org ? "#{said} → #{org.name}" : "#{said} (no está en Organizaciones)")
    org
  end

  def ask_line
    return 'Ya le preguntaste de qué empresa escribe: no lo vuelvas a preguntar.' if state['empresa_preguntada']

    'NO SABEMOS DE QUÉ EMPRESA ESCRIBE: cuando ya entendiste qué necesita (no en el saludo, y no en el mismo mensaje ' \
      'en que le das una solución), pregúntale UNA vez de qué empresa nos escribe y su correo, si no lo tienes; guárdalo ' \
      'con identificar_empresa.'
  end

  def save(org, said, email)
    @saved = { org: org }
    link(org, said)
    @saved[:duplicate] = save_email(email)
    Motor2::CustomerIdentity.by_domain!(contact) unless contact.organization
  end

  def link(org, said)
    if org
      contact.update!(organization: org) unless contact.organization
      note("se identificó como de «#{org.name}» (lo dijo el cliente; confírmalo si hace falta).")
    else
      attrs = contact.additional_attributes.to_h.merge('company_name' => said)
      contact.update!(additional_attributes: attrs)
      note("dice ser de «#{said}», que no está en Organizaciones. Lígalo a la correcta o márcalo como prospecto.")
    end
  end

  # El correo que dio: si ya es de otro contacto, no se pisa (posible duplicado).
  def save_email(email)
    return false unless email.match?(URI::MailTo::EMAIL_REGEXP) && contact.email.blank?

    other = config.account.contacts.where('LOWER(email) = ?', email.downcase).where.not(id: contact.id).first
    return contact.update(email: email) && false unless other

    note("posible duplicado: el correo #{email} ya es de «#{other.name}» (contacto ##{other.id}). Si es la misma persona, únelos con Unir contactos.")
    true
  end

  def note(text)
    tracking = @turn.tracking
    conversation = @turn.conversation
    return unless tracking && conversation

    @turn.after_send { Motor2::Delivery.note(tracking, conversation, format(NOTE, agent: config.name, text: text)) }
  end
end

# frozen_string_literal: true

# Los puestos de los agentes listos. Cada puesto es un archivo global en config/ready_agents
# (como las guías de Dali): si lo mejoramos, mejora para todas las empresas. Los que aún no
# están listos salen en la pantalla como «Próximamente».
module ReadyAgents::Catalog
  DIR = Rails.root.join('config/ready_agents')
  SOON = [
    { kind: 'customers', title: 'Atención a clientes',
      summary: 'Atiende a tus clientes: dudas, estado de su caso o servicio, quejas, y pasa a tu equipo lo que no puede resolver.' },
    { kind: 'collections', title: 'Cobranza',
      summary: 'Recuerda pagos pendientes, negocia la fecha y consigue el pago o la promesa de pago.' },
    { kind: 'campaign_seller', title: 'Vendedor de campaña',
      summary: 'Le escribe a una lista de contactos con una oferta concreta y detecta a quién le interesa.' }
  ].freeze

  module_function

  def all
    ReadyAgent::KINDS.map { |kind| entry(kind).merge(available: true) } + SOON.map { |s| s.merge(available: false) }
  end

  def entry(kind)
    meta, = parse(kind)
    { kind: kind, title: meta['title'], summary: meta['summary'] }
  end

  # Las instrucciones del puesto (lo que va en el prompt).
  def instructions(kind)
    parse(kind).last
  end

  def parse(kind)
    @cache ||= {}
    @cache[kind] = nil if Rails.env.development?
    @cache[kind] ||= begin
      text = File.read(DIR.join("#{kind}.md"))
      _, front, body = text.split(/^---\s*$/, 3)
      [YAML.safe_load(front.to_s) || {}, body.to_s.strip]
    end
  end
end

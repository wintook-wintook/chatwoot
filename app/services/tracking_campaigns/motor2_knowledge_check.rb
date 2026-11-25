# frozen_string_literal: true

# Campaña con IA — la parte de la revisión antes de lanzar (Motor2Check) que mira lo que sabe la IA: la ficha, la
# palabra clave del objetivo «lo hace por su cuenta» y las ligas (que la del paquete vaya en su texto).
class TrackingCampaigns::Motor2KnowledgeCheck
  def initialize(campaign)
    @campaign = campaign
    @brief = campaign.brief.to_h
  end

  # La ficha, la palabra clave y las ligas (TrackingCampaigns::CampaignKit).
  def call
    return [] if @brief['kind'] == 'survey'

    [facts_item, keyword_item, *link_items].compact
  end

  def facts_item
    return item(:facts, 'ok', 'La ficha tiene lo que sabe la IA.') if @brief['facts'].present? || Array(@brief['objections']).any?

    return item(:facts, 'ok', 'La oferta tiene sus productos del Catálogo.') if Array(@brief['products']).any?

    item(:facts, 'warning', "La ficha está vacía: la IA solo sabrá el nombre y la información que se manda. Llénala en #{step}.")
  end

  def keyword_item
    return nil unless @brief['offer_goal'] == 'external'
    return item(:keyword, 'ok', "Lo logra cuando escribe «#{@brief['goal_keyword']}».") if @brief['goal_keyword'].present?

    item(:keyword, 'error', 'El objetivo es que lo haga por su cuenta: escribe la palabra con la que avisa que ya lo hizo (p. ej. REGISTRADO).')
  end

  def link_items
    return [item(:links, 'warning', "Agrega en #{link_step} la liga donde lo hace (registro, compra, pago).")] if needs_link?
    return [] unless package_text?
    return [] if @brief['kind'] == 'invite' # en Invitar se pega sola al final de la información (Skills::Campaign#with_registration)

    links.select { |l| l['use'] == 'package' && content.exclude?(l['url']) }.map do |l|
      item(:"link_#{l['name']}", 'warning', "La liga «#{l['name']}» va con la información, pero no está en su texto (en «Mensajes»).")
    end
  end

  def package_text? = @campaign.inbox&.whatsapp? && content.present?

  def links = Array(@brief['links'])

  def content = @brief['content'].to_s

  def needs_link? = links.none? && @brief['offer_goal'] == 'external'

  private

  # Dónde se llena: Invitar lo tiene en «El evento».
  def step = { 'invite' => '«El evento»', 'offer' => '«La oferta»', 'reactivate' => '«Qué les ofreces»' }.fetch(@brief['kind'], '«La ficha»')

  # La liga de compra de Ofrecer y Reactivar va junto a la palabra clave.
  def link_step = %w[offer reactivate].include?(@brief['kind']) ? '«Cuando le interesa»' : step

  def item(key, level, text) = { key: key, level: level, text: text }
end

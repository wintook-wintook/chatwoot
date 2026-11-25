# frozen_string_literal: true

# Campaña con IA · Ofrecer — los «Casos» de la promoción (TrackingCampaigns::Motor2Cases):
#   quote    «¿Me lo cotizas?»: si la IA cotiza, debe ser con el precio de promoción (no el normal del Catálogo)
#   expired  «¿Todavía sigue la promoción?» con la vigencia vencida: dice que terminó y no ofrece el precio de promoción
class TrackingCampaigns::OfferCases
  def initialize(function, answers, make)
    @function = function
    @answers = answers.to_h
    @make = make
  end

  def cases
    return [] unless %w[offer reactivate].include?(@function.purpose) && promo

    [quote_case, expired_case].compact
  end

  private

  # El primer producto con precio de promoción: [catálogo, precio].
  def promo
    @promo ||= Array(@answers['products']).lazy.filter_map do |row|
      item = @function.config.account.catalog_items.find_by(id: row['catalog_item_id'])
      [item, row['promo_price'].to_d] if item && row['promo_price'].present?
    end.first
  end

  # Como lo diría cualquiera: «1,800» (sin centavos ni signo).
  def amount = ActiveSupport::NumberHelper.number_to_delimited(promo[1].to_i)

  def quote_case
    return unless @function.respond_to?(:quote_mode) && @function.quote_mode.to_s != 'off'

    @make.call('quote', 'Pide cotización: con el precio de promoción', "Me interesa, ¿me lo cotizas? Quiero 1 de #{promo[0].name}",
               expect: { any: %w[cotizar], says: amount })
  end

  def expired_case
    past = @answers.merge('valid_until' => Date.current.yesterday.iso8601)
    @make.call('expired', 'La promoción ya venció', '¿Todavía sigue la promoción?',
               expect: { not_says: amount, none: %w[cotizar] }, answers: past)
  end
end

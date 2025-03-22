# class Webhooks::WhatsappController < ActionController::API
#   include MetaTokenVerifyConcern

#   def process_payload
#     modified_params = transform_payload(params.to_unsafe_hash)
#     Webhooks::WhatsappEventsJob.perform_later(modified_params)
#   end

#   private

#   def valid_token?(token)
#     channel = Channel::Whatsapp.find_by(phone_number: params[:phone_number])
#     whatsapp_webhook_verify_token = channel.provider_config['webhook_verify_token'] if channel.present?
#     token == whatsapp_webhook_verify_token if whatsapp_webhook_verify_token.present?
#   end

#   def transform_payload(payload)
#     if payload.dig(:entry, 0, :changes, 0, :value, :messages, 0, :type) == 'order'
#       order_details = payload.dig(:entry, 0, :changes, 0, :value, :messages, 0, :order, :product_items)
#       order_text = build_order_text(order_details)

#       payload[:entry][0][:changes][0][:value][:messages][0][:type] = 'text'
#       payload[:entry][0][:changes][0][:value][:messages][0][:text] = { body: order_text }
#       payload[:entry][0][:changes][0][:value][:messages][0].delete(:order)
#     end

#     payload
#   end

#   def build_order_text(order_details)
#     order_text = "**Solicitud de Pedido:**\n\n"
#     order_details.each do |item|
#       order_text += "**Producto :** #{item[:product_retailer_id]}\n"
#       order_text += "**Cantidad :** #{item[:quantity]}\n"
#       order_text += "**Precio :** $#{format_price(item[:item_price])}\n"
#       order_text += "**Moneda :** #{item[:currency]}\n"
#       order_text += "\n\n"
#     end

#     order_text
#   end

#   def format_price(price)
#     # Convierte el precio a un formato de moneda con dos decimales y separadores de miles
#     "%.2f" % (price)
#   end
# end
class Webhooks::WhatsappController < ActionController::API
  include MetaTokenVerifyConcern
  include HTTParty

  def process_payload
    # WebhookJob.perform_later('https://webhook.site/9e2659b6-6448-46cc-a3f4-8ee5fd7dfab2', params.to_unsafe_hash)
    modified_params = transform_payload(params.to_unsafe_hash)
    Webhooks::WhatsappEventsJob.perform_later(modified_params)
  end

  private

  # Verifica si el token es válido
  def valid_token?(token)
    channel = Channel::Whatsapp.find_by(phone_number: params[:phone_number])
    whatsapp_webhook_verify_token = channel.provider_config['webhook_verify_token'] if channel.present?
    token == whatsapp_webhook_verify_token if whatsapp_webhook_verify_token.present?
  end

  # Transforma el payload si es un mensaje de tipo "order"
  def transform_payload(payload)
    if payload.dig(:entry, 0, :changes, 0, :value, :messages, 0, :type) == 'order'
      order_details = payload.dig(:entry, 0, :changes, 0, :value, :messages, 0, :order, :product_items)
      catalog_id = payload.dig(:entry, 0, :changes, 0, :value, :messages, 0, :order, :catalog_id)
      order_text = build_order_text(order_details, catalog_id)

      payload[:entry][0][:changes][0][:value][:messages][0][:type] = 'text'
      payload[:entry][0][:changes][0][:value][:messages][0][:text] = { body: order_text }
      payload[:entry][0][:changes][0][:value][:messages][0].delete(:order)
    end

    payload
  end

  # Construye el texto del pedido con las descripciones de los productos
  def build_order_text(order_details, catalog_id)
    # Obtén el canal basado en el número de teléfono
    channel = Channel::Whatsapp.find_by(phone_number: params[:phone_number])

    if channel.present?
      # Extrae el token de acceso y el ID del catálogo desde el provider_config
      access_token = channel.provider_config['api_key']
      business_account_id = channel.provider_config['business_account_id']



      # Obtén los datos de los productos desde el catálogo de Meta
      product_items_with_details = get_product_details(order_details, access_token, business_account_id, catalog_id)

      # order_text = "Solicitud de Pedido:\n\n"
      # product_items_with_details.each do |item|
      #   # order_text += "access_token : #{access_token}\n"
      #   # order_text += "business_account_id : #{business_account_id}\n"
      #   order_text += "Producto : #{item[:name]}\n"
      #   order_text += "Descripción : #{item[:description]}\n"
      #   order_text += "Cantidad : #{item[:quantity]}\n"
      #   order_text += "Precio : $#{format_price(item[:price])}\n"
      #   order_text += "Moneda : #{item[:currency]}\n"
      #   order_text += "\n\n"
      # end

      # order_text

      order_text = "**Solicitud de Pedido:**\n\n"
      total = 0

      product_items_with_details.each do |item|
        subtotal = item[:quantity] * item[:price]
        total += subtotal

        order_text += "**Producto :** #{item[:name]}\n"
        order_text += "**Descripción :** #{item[:description]}\n"
        order_text += "**Cantidad :** #{item[:quantity]}\n"
        order_text += "**Precio :** $#{format_price(item[:price])}\n"
        order_text += "**Subtotal :** $#{format_price(subtotal)}\n"
        order_text += "**Moneda :** #{item[:currency]}\n"
        order_text += "\n\n"
      end

      # Agregar el total al final
      order_text += "**Total Estimado :** $#{format_price(total)}\n"

      order_text
    else
      "Error: No se encontró el canal para el número de teléfono #{params[:phone_number]}"
    end
  end

  # Obtiene los detalles de los productos desde el catálogo de Meta
  def get_product_details(product_items, access_token, business_account_id, catalog_id)
    url = "https://graph.facebook.com/v21.0/#{catalog_id}/products"
    params = {
      access_token: access_token,
      fields: 'name,retailer_id,description',
      limit: 100 # Número máximo de productos por solicitud
    }
    products_data = []
    while url
      response = HTTParty.get(url, query: params)
      if response.success?
        data = response.parsed_response['data']
        products_data += data
        # Paginación: obtener la siguiente página si existe
        pagination = response.parsed_response['paging']
        if pagination && pagination['next']
          url = pagination['next']
        else
          url = nil
        end
      else
        puts "Error al obtener los productos: #{response.body}"
        break
      end
    end

      # Combina los detalles de los productos con los items del pedido
      product_items.map do |item|
        product = products_data.find { |p| p['retailer_id'] == item[:product_retailer_id] }
        if product
          item.merge(
            name: product['name'],
            description: product['description'] || 'Descripción no disponible',
            price: product['price'] || item[:item_price],
            currency: product['currency'] || item[:currency]
          )
        else
          item.merge(
            name: item[:product_retailer_id],
            description: 'Descripción no disponible',
            price: item[:item_price],
            currency: item[:currency]
          )
        end
      end
  end

  # def get_product(product_items, access_token, business_account_id, catalog_id)
  #   url = "https://graph.facebook.com/v21.0/#{catalog_id}/products"
  #   params = {
  #     access_token: access_token,
  #     fields: 'name,retailer_id',
  #     limit: 100 # Número máximo de productos por solicitud
  #   }
  
  #   productos = []
  #   while url
  #     response = HTTParty.get(url, query: params)
  
  #     if response.success?
  #       data = response.parsed_response['data']
  #       productos += data
  
  #       # Paginación: obtener la siguiente página si existe
  #       pagination = response.parsed_response['paging']
  #       if pagination && pagination['next']
  #         url = pagination['next']
  #       else
  #         url = nil
  #       end
  #     else
  #       puts "Error al obtener los productos: #{response.body}"
  #       break
  #     end
  #   end
  
  #   productos
  # end
  

  # Formatea el precio para mostrarlo correctamente
  def format_price(price)
    # Convierte el precio a un formato de moneda con dos decimales y separadores de miles
    "%.2f" % (price)
  end
end
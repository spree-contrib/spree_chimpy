require_relative 'customer_upserter'
require_relative 'products'
require_relative 'spree_order_upserter'

module Spree::Chimpy
  module Interface
    class OrderUpserter < SpreeOrderUpserter

      def order_hash
        data = common_hash
          data[:financial_status] = @order.payment_state || ""
          data[:fulfillment_status] = @order.shipment_state || ""
          data[:shipping_total] = @order.ship_total.to_f

        data
      end

      def perform_upsert
        data = order_hash
        log "Adding order #{@order.number} for #{data[:customer][:id]}"
        if (data[:campaign_id])
          log "Order #{@order.number} is linked to campaign #{data[:campaign_id]}"
        end
        begin
          find_and_update_order(data)
        rescue Gibbon::MailChimpError => e
          log "Order #{@order.number} Not Found, creating order"
          create_order(data)
        end
      end

      def find_and_update_order(data)
        # retrieval is checks if the order exists and raises a Gibbon::MailChimpError when not found
        store_api_call.orders(@order.number).retrieve(params: { "fields" => "id" })
        log "Order #{@order.number} exists, updating data"
        store_api_call.orders(@order.number).update(body: data)
      end

      def create_order(data)
        begin
          store_api_call
            .orders
            .create(body: data)
        rescue Gibbon::MailChimpError => e
          log "Unable to create order #{@order.number}. [#{e.raw_body}]"
        end
      end
    end
  end
end

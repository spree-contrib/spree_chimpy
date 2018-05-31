require_relative 'customer_upserter'
require_relative 'products'
require_relative 'spree_order_upserter'

module Spree::Chimpy
  module Interface
    class CartUpserter < SpreeOrderUpserter

      def cart_hash
        data = common_hash
        data[:checkout_url] = "#{Spree::Store.current.url}/orders/#{@order.number}/edit"

        data
      end

      def perform_upsert
        if (@order.completed?)
          remove_cart
        else
          add_or_update_cart
        end
      end

      def add_or_update_cart

        data = cart_hash
        log "Adding cart #{@order.number} for #{data[:customer][:id]}"

        if (data[:campaign_id])
          log "Cart #{@order.number} is linked to campaign #{data[:campaign_id]}"
        end
        begin
          find_and_update_cart(data)
        rescue Gibbon::MailChimpError => e
          log "Cart #{@order.number} Not Found, creating cart"
          create_cart(data)
        end
      end

      def remove_cart
        begin
          store_api_call.carts(@order.number).delete
          # NOTE: Once an Order is complete, we want to remove the Cart record
          # from MailChimp because it is no longer relevant.
          #
          #     NOTE: If the cart is not removed, then it would be included in
          #     automated Abandoned Cart campaigns, which should not happen if
          #     the customer has completed their order.
        rescue Gibbon::MailChimpError => e
          log "Unable to remove cart #{@order.number}. [#{e.raw_body}]"
        end
      end

      def find_and_update_cart(data)
        unless (mail_chimp_order_exists?)
          store_api_call.carts(@order.number).retrieve(params: { "fields" => "id" })
          log "Cart #{@order.number} exists, updating data"
          store_api_call.carts(@order.number).update(body: data)
        end
      end

      def create_cart(data)
        unless(mail_chimp_order_exists?)
          store_api_call
            .carts
            .create(body: data)
        end
      rescue Gibbon::MailChimpError => e
        log "Unable to create cart #{@order.number}. [#{e.raw_body}]"

      end

      # This method exists for validation purposes. If an ORDER has already
      # been sent to MailChimp, then we do not want to add a cart.
      #
      # NOTE: This should be prevented by a call to Order.completed? in the
      # OrdersController before attempting the upsert, but this was added as
      # a failsafe
      def mail_chimp_order_exists?
        begin
          # Check MailChimp for an Order with the associated ID
          store_api_call.orders(@order.number).retrieve(params: { "fields" => "id" })
          # NOTE: This API call will raise a Gibbon::MailChimpError if the Order
          #       does not exist, so any non-error return from the above should
          #       result in a FALSE return from this method.

          true ## The order EXISTS
        rescue Gibbon::MailChimpError => e
          # NOTE: If we encounter this error here, it means no ORDER exists in
          #       MailChimp for the specified ID. In this case, that's just fine
          #       so we want to swallow the error and move on.

          false # The order DOES NOT EXIST
        end
      end
    end
  end
end

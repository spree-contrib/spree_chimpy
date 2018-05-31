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
        unless (mail_chimp_order_exists?) # If an order already exists, we can skip this entirely

          log "Syncing removed line items for card #{@order.number}"
          sync_line_item_deletes

          log "Cart #{@order.number} exists, updating data"
          store_api_call.carts(@order.number).update(body: data)
        end
      end

      def sync_line_item_deletes()
        # NOTE: The PATCH request for CARTS in the MailChimp API does not correctly sync
        # the REMOVAL of items from the cart. If we change the QUANTITY from 10 to 15,
        # that change syncs correctly, but if we remove an item from my cart in the sore's
        # UI, that line item is NOT removed from the cart in MailChimp.
        #
        # The following block resolves this error by manually deleting CART LINES that
        # were REMOVED from the ORDER

        cart_line_items = store_api_call.carts(@order.number).retrieve(params: {"fields" => "lines"}).body['lines']
        # Get all the LINES attached to this CART in MailChimp

        cart_line_items.each do |cart_item|
          # For each LINE returned by MailChimp, verify that this line is still present
          # on the ORDER. If it's not, then REMOVE it.

          if (@order.line_items.any?)
            # This check is only necessary if the ORDER actually has LINE ITEMS

            has_match = false; # By default, we assume the line item is to be deleted.

            @order.line_items.each do |order_item|
              # Loop through ALL ITEMS in the ORDER
              if ("line_item_#{order_item.id}" == cart_item['id'])
                # As soon as we find a match, BREAK the loop
                has_match = true
                break
              end
            end

            if (!has_match)
              # No matching line item was found on the ORDER. Delete this item from the CART
              Rails.logger.info "[INFO: SpreeChimpy]:    #{cart_item['id']} has been removed from the cart. Deleting the associated line item in MailChimp"
              store_api_call.carts(@order.number).lines(cart_item['id']).delete
            end
          else
            # If there are no LINE ITEMS for the order, just remove the entire cart
            Rails.logger.info "[INFO: SpreeChimpy]:    #{@order.number} is empty. Deleting the cart from MailChimp"
            store_api_call.carts(@order.number).delete
          end
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

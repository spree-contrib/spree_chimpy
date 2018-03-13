module Spree::Chimpy
  module Interface
    class SpreeOrderUpserter
      delegate :log, :store_api_call, to: Spree::Chimpy

      # This is a generic Upserter Class for Spree Orders
      #
      # Spree uses a single object to manage Carts and Orders and relies on the
      # Order's status to differentiate between the two.
      #
      # MailChimp, however has a distinct API endpoint for each, which requires
      # Carts and Orders to be handled independently. Most of this process is
      # identical -- the only significant difference is in the URL of the API
      # call and the structure of the JSON object passed to MailChimp.
      #
      # This class handles the common processes, and the order_upserter / cart_upserter
      # handle the custom requirements

      def initialize(order)
        # NOTE: We intentionally use the variable name of @order to maintain
        # consistency with the Spree object (which uses the Order object
        # interchangeably for both Carts and Orders)
        @order = order
      end

      def customer_id
        # Get the Customer ID
        @customer_id ||= CustomerUpserter.new(@order).ensure_customer
        # Ensures that a Customer entity exists in MailChimp's DB
      end

      def upsert
        return unless customer_id

        Products.ensure_products(@order)
        # Ensure that any products for this @order exist before doing anything
        # else.
        #
        # This will make POST calls for products that are not already registered
        # inside MailChimp

        perform_upsert
      end

      protected

      def perform_upsert
        log "[Spree Chimpy: Error]:      Upsert method is not implemented"
      end

      # This method generates a hash object containing the common data elements
      # shared by both Carts and Orders
      #
      # NOTE: Though both carts and orders require the lines: parameter, the
      # structure of the data IN that parameter differs slightly for each endpoint
      #
      # NOTE: Despite the different endpoints, carts and orders are mutually exclusive
      # elements. When adding an ORDER (completed order), any associated carts
      # (in-progress order) should be removed.
      #
      # Using Spree's Order Number as the ID for both Carts and Orders helps facilitate
      # this pairing.
      def common_hash
        source = @order.source

        lines = @order.line_items.map do |line|
          line_item_hash(line)
        end

        data = {
          id:                     @order.number,
          lines:                  lines,
          order_total:            @order.total.to_f,
          currency_code:          @order.currency,
          processed_at_foreign:   @order.completed_at ? @order.completed_at.to_formatted_s(:db) : "",
          updated_at_foreign:     @order.updated_at.to_formatted_s(:db),
          tax_total:              @order.try(:included_tax_total).to_f + @order.try(:additional_tax_total).to_f,
          customer: {
            id: customer_id
          }
        }

        if source
          data[:campaign_id] = source.campaign_id
        end

        data
      end

      def line_item_hash(line_item)
        variant = line_item.variant
        {
          id: "line_item_#{line_item.id}",
          product_id:    Products.mailchimp_product_id(variant),
          product_variant_id: Products.mailchimp_variant_id(variant),
          price:          variant.price.to_f,
          quantity:           line_item.quantity
        }
      end
    end
  end
end

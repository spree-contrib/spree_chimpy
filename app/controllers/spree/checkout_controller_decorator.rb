Spree::CheckoutController.class_eval do

  before_action :sync_with_mail_chimp

  def sync_with_mail_chimp
    unless(@order.nil?)
      @order.notify_mail_chimp
    end
  end
end

Spree::OrdersController.class_eval do

  before_action :sync_with_mail_chimp, except: :show

  def sync_with_mail_chimp
    unless(current_order.nil?)
      current_order.notify_mail_chimp
    end
  end
end

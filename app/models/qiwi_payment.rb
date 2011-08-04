# писался по примеру Creditcard
class QiwiPayment < ActiveRecord::Base
  has_many :payments, :as => :source
  validates :number, :presence => true, :on => :create

  # process!(payment) - выставление счета
  def process!(payment)
      purchase(payment.amount.to_f, payment)
  end

  # как я понял оплата меньше чем сумма
  # но возможно операция на шлюзе с деньгами
  # FIXME вникнуть
  def credit(payment)
  end
  def can_credit?(payment)
    return false unless payment.state == "completed"
    return false unless payment.order.payment_state == "credit_owed"
    payment.credit_allowed > 0
  end


  # выставление счета
  def purchase(amount,payment)
    payment_gateway = payment.payment_method
    check_environment(payment_gateway)
    code = payment_gateway.set_task(payment,"purchase")
    #payment.fail! if code != "0"
    record_log(payment,code)
  end

  # Indicates whether its possible to void the payment.
  def can_void?(payment)
    payment.state == "void" ? false : true
  end

  def void(payment)
    can_void?(payment)
    payment_gateway = payment.payment_method
    check_environment(payment_gateway)
    code = payment_gateway.set_task(payment,"void")
    payment.void! if code == "0"
    record_log(payment,code)
  end

  def record_log(payment, response)
    payment.log_entries.create(:details => response.to_yaml)
  end
  # Saftey check to make sure we're not accidentally performing operations on a live gateway.
  # Ex. When testing in staging environment with a copy of production data.
  def check_environment(gateway)
    return if gateway.environment == Rails.env
    message = I18n.t(:gateway_config_unavailable) + " - #{Rails.env}"
    raise Spree::GatewayError.new(message)
  end
end

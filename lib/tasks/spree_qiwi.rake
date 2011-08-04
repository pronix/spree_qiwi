namespace :db do
desc 'check invoices in qiwi'
task :check_invoices do
  require "#{File.expand_path(File.dirname(__FILE__) + "/../../../spree/sandbox/")}/config/environment"
  ActiveRecord::Base.establish_connection(Rails.env.to_sym)

# цикл по 99 заказов проверяется
  orders = Payment.from_qiwi.pending.select(:order_id).collect(&:order_id)
  orders.each_slice(99).to_a.each do |arr|
    q = Gateway::Qiwi.first
    xml = q.get_invoices_status(arr)
    enc_str = q.request_str(xml)
    http = Net::HTTP.new('ishop.qiwi.ru',80)
    resp, data = http.post('/xml', enc_str,{})
    data = data.to_s
    # если код ответа 0 т.е. обработан запрос верно и корректно ответили
    # то уже работаем по заказам
    nk = Nokogiri::XML(data)


    if nk.search("result-code").first.try(:child).to_s == "0"

      nk.xpath('//bill').each do |x|
        order = Order.find_by_id(x.attr(:id))
        # если оплачен
        if x.attr(:status) == "60"
          # FIXME тут считается что платеж за один заказ только один
          # хотя дижек предусматривает возможность заплатить по частям
          order.payment.complete!
          # если ошибка какая-то
        elsif x.attr(:status) == "150" || x.attr(:status) == "151" || x.attr(:status) == "160" || x.attr(:status) == "161"
          # FIXME та же фигня что и в предыдущем случае
          order.payment.fail!
        end
      end #end each bill

    end

  end #end orders.each_slice


end #end task
end

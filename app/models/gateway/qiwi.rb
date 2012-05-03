#1.6. Формат параметров запросов
#Параметр               Формат
#terminal-id            Целое число (например, 2042)
#password               Строка
#txn-id                 Строка цифр и латинских букв без пробелов,длиной до 30 байт
#to-account             Целое десятизначное число
#amount                 Число, разделителем является точка (например,123.45)
#comment                Строка, длиной до 255 байт
#create_agt             1/0
#ltime                  Число, разделителем является точка (например,0.25)
#ALARM_SMS              1/0
#ACCEPT_CALL            1/0
#
#
#ПРИЛОЖЕНИЕ А: Справочник кодов завершения
#Код завершения
#Описание
#0 Успех
#13 Сервер занят, повторите запрос позже
#150 Ошибка авторизации (неверный логин/пароль)
#210 Счет не найден
#215 Счет с таким txn-id уже существует
#241 Сумма слишком мала
#242 Превышена максимальная сумма платежа – 15 000р.
#278 Превышение максимального интервала получения списка счетов
#298 Агента не существует в системе
#300 Неизвестная ошибка
#330 Ошибка шифрования
#339 Не пройден контроль IP-адреса
#370 Превышено максимальное кол-во одновременно выполняемых запросов
#
#
class Gateway::Qiwi < Gateway
  require 'nokogiri'
  require 'digest/md5'
  require 'net/http'
  require 'uri'
  attr_accessor :qiwi_number
  preference :merchant_id, :string
  preference :password, :string

  # отправляет запрос
  # Запрос передается методом POST в теле HTTP-запроса и имеет вид:
  # 1. идентификатор зашифрованного сообщения - «qiwi»
  # 2. 10 цифр ID агента (номер магазина) — 1234567890, если ID меньше 10 цифр, то в начало добавляются нули (0000001234)
  # 3. перевод каретки (в Си и Ява «\n»)
  # 4. Закодированное base-64 тело зашифрованного запроса, в одну строку. Шифрование производиться по алгоритму DES3.
  def request_str(xml)
    "qiwi" + sprintf("%010d",preferences["merchant_id"]) + "\n" + encrypt(xml)
  end

  # как я понимаю информация дл решения тут http://www.ruby-forum.com/topic/179794
  # фантастическая херня - даже в пхп все проще работает
  def encrypt(string)
    # количество символов кратное 8
    string = string + " "*(7-string.size%8.0)
    result = `echo '#{string}' | openssl enc -des-ede3 -e -nopad -nosalt -a -K #{generate_key} -iv 0 -p`.split(/\niv \=[0..9]+\n/).last
    result
  end

  # генерилка ключа - верно работает
  # FIXME require cache and regenerate after change pass or merchant_id
  def generate_key
    sh = Digest::MD5.hexdigest(preferences["password"]).to_s.split('')
    a=sh.to16pairs
    b = Digest::MD5.hexdigest(preferences["merchant_id"]+sh.join).to_s.split('').to16pairs

    key = []
    # забиваем нулями массив
    24.times do |i|
       if i >= 16
         key[i] = b[i-8]
       elsif i >=8 && i <16
         key[i] = (a[i].hex^b[i-8].hex).to_s(16)
       else
         key[i] = a[i]
       end
    end
    key.join.upcase
  end
  # create xml for create new invoice
  #1.2.1. Запрос
  #<?xml version="1.0" encoding="utf-8"?>
  #<request>
  #<protocol-version>4.00</protocol-version>
  #<request-type>30</request-type>
  #<terminal-id>5555</terminal-id>
  #<extra name="password">password</extra>
  #<extra name="txn-id">123.45</extra>
  #<extra name="to-account">9268888888</extra>
  #<extra name="amount">98413</extra>
  #<extra name="comment">test</extra>
  #<extra name="create-agt">1</extra>
  #<extra name="ltime">48.5</extra>
  #<extra name="ALARM_SMS">1</extra>
  #<extra name="ACCEPT_CALL">1</extra>
  #</request>
  #Описание:
  #• <request–type> – тип запроса (30 для создания счета);
  #• <terminal–id> – идентификатор (логин) провайдера;
  #• Экстра–поля:
  #− "password" – пароль;
  #− "txn–id" – уникальный номер счета;
  #− "to–account" – десятизначный номер абонента;
  #− "amount" – сумма;
  #− "comment" – комментарий;
  #−
  #"create–agt" – флаг необходимости создания агента, если агента не существует в системе
  #(0/1);
  #ПРИМЕЧАНИЕ
  #Если флаг установлен в 0, то при попытке создания счета будет возвращаться соответствующая
  #ошибка.
  #Если флаг установлен в 1, то при попытке создания счета будет создан новый агент.
  #− "ltime" – время действия счета в часах, по истечению которого оплата невозможна,
  #считается от момента создания;
  #− "ALARM_SMS" – sms оповещение пользователя о выставлении счета (0/1);
  #− "ACCEPT_CALL" – звонок-оповещение пользователя о выставлении счета (0/1).
  #
  #1.2.2. Ответ
  #<response>
  #<result-code fatal="false">0</result-code>
  #</response>
  #Описание:
  #•
  #<result-code> – код завершения операции.
  #
  #      gateway.create_invoice({'txn-id' => 9090977,
  #      'to-account' => "9210073447",
  #      'amount' => 500,
  #      'comment' => 'hello i need new agent',
  #      'create-agt' => true})
  def create_invoice(hash)
     builder =  Nokogiri::XML::Builder.new_for_qiwi(preferences["merchant_id"],preferences["password"],30) do
         extra hash['txn-id'], :name => "txn-id"
         extra hash['to-account'], :name => "to-account"
         extra hash['amount'], :name => "amount"
         extra hash['comment'], :name => "comment"
         extra hash['create-agt'] ? 1 : 0, :name => "create-agt"
         extra 48, :name => "ltime"
         extra 1, :name => "ALARM_SMS"
         extra 1, :name => "ACCEPT_CALL"
     end
     builder.to_xml
  end

  # create xml for many invoices
=begin
      gateway.create_invoices({
        "terminal-id" => 5555,
        "password" => "password",
        "bills" => [{
          "comment" => "",
          "to-account" => "8888888888",
          "amount" => "0.10",
          "txn-id" => "FFC9",
          "ALARM_SMS" => 0,
          "ACCEPT_CALL" => 1,
          "create-agt" => 1
        },{
          "comment" => "",
          "to-account" => "8888888889",
          "amount" => "0.10",
          "txn-id" => "FFD0",
          "ALARM_SMS" => 0,
          "ACCEPT_CALL" => 0,
          "create-agt" => 0
        }]
      })
=end
  def create_invoices(hash)
     builder =  Nokogiri::XML::Builder.new_for_qiwi(preferences["merchant_id"],preferences["password"],77) do
         bills do

           # iteration for each bill
           hash["bills"].each do |hash_bill|
             bill do
               extra hash_bill['comment'], :name => "comment"
               extra hash_bill['to-account'], :name => "to-account"
               extra hash_bill['amount'], :name => "amount"
               extra hash_bill['txn-id'], :name => "txn-id"
               extra hash_bill['ALARM_SMS'], :name => "ALARM_SMS"
               extra hash_bill['ACCEPT_CALL'], :name => "ACCEPT_CALL"
               extra 48, :name => "ltime"
               extra hash_bill['create-agt'], :name => "create-agt"
             end
           end
           # end iteration

       end
     end
     builder.to_xml
  end

=begin
Запрос на отмену счета
1.4.1. Запрос
<?xml version="1.0" encoding="utf-8"?>
<request>
<protocol-version>4.00</protocol-version>
<request-type>29</request-type>
<terminal-id>5555</terminal-id>
<extra name="password">password</extra>
<extra name="txn-id">FF00</extra>
<extra name="status">reject</extra>
</request>
Описание:
• <request-type> – тип запроса (29 для изменения счета);
• <terminal-id> – идентификатор (логин) провайдера;
• Экстра-поля:
− "password" – пароль;
− "txn-id" – номер счета, указанный при создании;
− "status" – новый статус счета (reject – отмена).
1.4.2. Ответ
<response>
<result-code fatal="false">0</result-code>
</response>
Описание:
•
<result-code> – код завершения операции.
=end
# "FF00"
  def reject_invoice(str)
     builder = Nokogiri::XML::Builder.new_for_qiwi(preferences["merchant_id"],preferences["password"],29) do
       extra str, :name => "txn-id"
       extra "reject", :name => "status"
     end
     builder.to_xml
  end

=begin
1.5. Запрос статусов счетов
1.5.1. Запрос
<?xml version="1.0" encoding="utf-8"?>
<request>
<protocol-version>4.0</protocol-version>
<request-type>33</request-type>
<terminal-id>5555</terminal-id>
<extra name="password">password</extra>
<bills-list>
<bill txn-id="FF00" />
<bill txn-id="FF01" />
</bills-list>
</request>
Описание:
• <request–type> – тип запроса (33 для получения статусов счетов);
• <terminal–id> – идентификатор (логин) провайдера;
• Экстра-поля:
− "password" – пароль;
− <bills-list> – список счетов:
− <bill> – счета с указанием txn-id счета.
ПРИМЕЧАНИЕ
Максимальное количество счетов в списке запроса – 999.
1.5.2. Ответ
<response>
<result-code fatal="false">0</result-code>
<bills-list>
<bill id="FF00" status ="150" sum="0.05" />
<bill id="FF01" status ="60" sum="0.05" />
</bills-list>
</response>
Описание:
  • <result-code> – код завершения операции.
  • <bill> – информация о счете:
  − id – идентификатор счета;
  − status – статус счета;
  − sum – сумма счета.

gateway.get_invoices_status(["FF00","FF01"])
#ПРИЛОЖЕНИЕ Б: Справочник статусов счетов
#Статус
#Описание
#50 Выставлен
#52 Проводится
#60 Оплачен
#150 Отменен (ошибка на терминале)
#151 Отменен (ошибка авторизации: недостаточно средств на балансе, отклонен абонентом при оплате с лицевого счета оператора сотовой связи и т.п.).
#160 Отменен
#161 Отменен (Истекло время)
=end
  def get_invoices_status(array)
     builder = Nokogiri::XML::Builder.new_for_qiwi(preferences["merchant_id"],preferences["password"],33) do
       send("bills-list") do
         array.each do |x|
           bill "txn-id" => x
         end
       end
     end
     builder.to_xml
  end

  # options for test mode
  def options
    if self.prefers? :test_mode
      self.class.default_preferences[:test] = true
    else
      self.class.default_preferences.delete(:test)
    end
    super
  end

  def method_type
    "qiwi"
  end

  def payment_source_class
    QiwiPayment
  end

  def payment_profiles_supported?
    false
  end

  #send request
  def send_request(str)
    begin
      http = Net::HTTP.new('ishop.qiwi.ru',80)
      resp, data = http.post('/xml', str,{})
      Nokogiri::XML(data.to_s).search("result-code").first.try(:child).to_s
    rescue=>e
      puts e
      logger.error e
    end
  end

  # set_task(payment,"void")
  # set_task(payment,"purchase")
  def set_task(payment,str)
    if str == 'purchase'
      hash = {  'txn-id' => payment.order_id,
              'to-account' => payment.source.number,
              'amount' => payment.amount.to_s,
              'comment' => "order for tradefast.ru num.#{payment.order_id}",
              'create-agt' => true}
      xml = create_invoice(hash)
    elsif str == "void"
      xml = reject_invoice(payment.order_id)
    end
    request = request_str(xml)
    code = send_request(request)
    code
  end
end

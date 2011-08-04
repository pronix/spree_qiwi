require 'spec_helper'

describe Gateway::Qiwi do
  let (:gateway) { Gateway::Qiwi.new}

  describe "options" do
    it "should include :test => true when :test_mode is true" do
      gateway.prefers_test_mode = true
      gateway.options[:test].should == true
    end

    it "should not include :test when :test_mode is false" do
      gateway.prefers_test_mode = false
      gateway.options[:test].should be_nil
    end
  end


  describe "запрос на создание счета" do
    it "should generate xml for create new invoice" do
      gateway.set_preference :password,'password'
      gateway.set_preference :merchant_id,'5555'
      gateway.save(:validate => false)
      gateway.create_invoice({'txn-id' => 9090977,
        'to-account' => "9210073447",
        'amount' => 500,
        'comment' => 'hello i need new agent',
        'create-agt' => true}).should == <<EOF
<?xml version="1.0" encoding="utf-8"?>
<request>
  <protocol-version>4.0</protocol-version>
  <request-type>30</request-type>
  <terminal-id>5555</terminal-id>
  <extra name="password">password</extra>
  <extra name="txn-id">9090977</extra>
  <extra name="to-account">9210073447</extra>
  <extra name="amount">500</extra>
  <extra name="comment">hello i need new agent</extra>
  <extra name="create-agt">1</extra>
  <extra name="ltime">48</extra>
  <extra name="ALARM_SMS">1</extra>
  <extra name="ACCEPT_CALL">1</extra>
</request>
EOF
    end
  end

  describe "создание нескольких счетов" do
    it "should generate xml for create many invoices" do
      gateway.set_preference :password,'password'
      gateway.set_preference :merchant_id,'5555'
      gateway.save(:validate => false)
      gateway.create_invoices({
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
      }).should == <<EOF
<?xml version="1.0" encoding="utf-8"?>
<request>
  <protocol-version>4.0</protocol-version>
  <request-type>77</request-type>
  <terminal-id>5555</terminal-id>
  <extra name="password">password</extra>
  <bills>
    <bill>
      <extra name="comment"></extra>
      <extra name="to-account">8888888888</extra>
      <extra name="amount">0.10</extra>
      <extra name="txn-id">FFC9</extra>
      <extra name="ALARM_SMS">0</extra>
      <extra name="ACCEPT_CALL">1</extra>
      <extra name="ltime">48</extra>
      <extra name="create-agt">1</extra>
    </bill>
    <bill>
      <extra name="comment"></extra>
      <extra name="to-account">8888888889</extra>
      <extra name="amount">0.10</extra>
      <extra name="txn-id">FFD0</extra>
      <extra name="ALARM_SMS">0</extra>
      <extra name="ACCEPT_CALL">0</extra>
      <extra name="ltime">48</extra>
      <extra name="create-agt">0</extra>
    </bill>
  </bills>
</request>
EOF
  end
end

  describe "reject invoice" do
    it "should generate xml for reject invoice" do
      gateway.set_preference :password,'password'
      gateway.set_preference :merchant_id,'5555'
      gateway.save(:validate => false)
      gateway.reject_invoice("FF00").should == <<EOF
<?xml version="1.0" encoding="utf-8"?>
<request>
  <protocol-version>4.0</protocol-version>
  <request-type>29</request-type>
  <terminal-id>5555</terminal-id>
  <extra name="password">password</extra>
  <extra name="txn-id">FF00</extra>
  <extra name="status">reject</extra>
</request>
EOF
    end
  end

  describe "get invoices status" do
    it "should generate xml for get invoices statuses" do
      gateway.set_preference :password,'testpass'
      gateway.set_preference :merchant_id,'15128'
      gateway.save(:validate => false)
      gateway.get_invoices_status(["FF00","FF01"]).should == <<EOF
<?xml version="1.0" encoding="utf-8"?>
<request>
  <protocol-version>4.0</protocol-version>
  <request-type>33</request-type>
  <terminal-id>15128</terminal-id>
  <extra name="password">testpass</extra>
  <bills-list>
    <bill txn-id="FF00"/>
    <bill txn-id="FF01"/>
  </bills-list>
</request>
EOF
    end
  end
  describe "шифрование" do
    it "should generate valid key" do
      gateway.set_preference :password,'testpass'
      gateway.set_preference :merchant_id,'15128'
      gateway.save(:validate => false)


        gateway.generate_key.should == "179AD45C6CE2CB97CF97B65FAD707C4E4A40D6F76834EB21"
    end
    it "should encrypt xml" do
      gateway.set_preference :password,'testpass'
      gateway.set_preference :merchant_id,'15128'
      gateway.save(:validate => false)
xml = %q(<?xml version="1.0" encoding="utf-8"?><request><request-type>3</request-type><protocol-version>4.0</protocol-version><terminal-id>15128</terminal-id><extra name="password">testpass</extra></request>)
    gateway.encrypt(xml).should == %q(CYsMeaTMTG/U01zcaVd9yvbSRDbyST+tMyeRjS0okJnpFuXPo+PByAP7PEX/Z/ui
5aAVFRhD9Ck1BBIdORXiJeWgFRUYQ/QpJWUgkSrC94+0Q70N6xBCx8dUvmf43dDn
jWYWCtIW4+qxyQW5Qf+n5FzGDZ6uLCwIo7e+DOuCir9nMaoGVaVB2djLYIdH0Des
2+Rtoh/spbT1/Rajlt/EHtnXtpGfe1uka6PeHJN0MPwVGr/gPVd6uDV3/M1afRnu
xI+VBBeKcbk=
)
    end
  end
end

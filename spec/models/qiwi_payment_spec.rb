require 'spec_helper'

describe QiwiPayment do

  context 'validation' do
    it { should have_valid_factory(:qiwi_payment) }
  end

  let(:order) { mock_model(Order, :update! => nil, :payments => []) }
  let(:payment_gateway) {Gateway::Qiwi.new}

  before(:each) do
    order.stub_chain(:payments, :reload => [])

    @qp = QiwiPayment.new
    @payment = Payment.create(:amount => 100, :order => order)

    @success_response = mock('gateway_response', :success? => true, :authorization => '123', :avs_result => {'code' => 'avs-code'})
    @fail_response = mock('gateway_response', :success? => false)
      payment_gateway.environment = 'test'
      payment_gateway.set_preference :test_mode, true
      payment_gateway.set_preference :password,'testpass'
      payment_gateway.set_preference :merchant_id,'15128'
      payment_gateway.save(:validate => false)
    @payment_gateway = payment_gateway

    @payment.stub :payment_method => @payment_gateway

    @qp.stub!(:gateway_options).and_return({})
    @qp.stub!(:minimal_gateway_options).and_return({})
  end

  context "#process!" do
    it "should purchase if with auto_capture" do
      @qp.should_receive(:purchase)
      @qp.process!(@payment)
    end
  end

  context "#purchase" do
    it "should call purchase on the gateway with the payment amount" do
      @qp.number = '9210073447'
      @payment.source = @qp
      @payment.save!(:validate => false)
      @qp.purchase(100, @payment)
    end
    it "should log the response" do
      @qp.number = '9210073447'
      @payment.source = @qp
      @payment.save!(:validate => false)
      @payment.log_entries.should_receive(:create).with(:details => anything)
      @qp.purchase(100, @payment)
    end
  end

  context "#void" do
    before do
      @payment.state = 'pending'
    end
    it "should call payment_gateway.void with the payment" do
      @qp.void(@payment)
    end
    it "should log the response" do
      @payment.log_entries.should_receive(:create).with(:details => anything)
      @qp.void(@payment)
    end
    context "if sucessfull" do
      it "should update the response_code with the authorization from the gateway" do
        @qp.void(@payment)
      end
      it "should void the payment" do
        @qp.should_receive(:void)
        @qp.void(@payment)
      end
    end
  end

  let(:qp) { QiwiPayment.new }

  context "when transaction is more than 12 hours old" do
    let(:payment) { mock_model(Payment, :state => "completed", :created_at => Time.now - 14.hours, :amount => 99.00, :credit_allowed => 100.00, :order => mock_model(Order, :payment_state => 'credit_owed')) }

    context "#can_credit?" do

      it "should be true when payment state is 'completed' and order payment_state is 'credit_owed' and credit_allowed is greater than amount" do
        qp.can_credit?(payment).should be_true
      end

      it "should be false when order payment_state is not 'credit_owed'" do
        payment.order.stub(:payment_state => 'paid')
        qp.can_credit?(payment).should be_false
      end

      it "should be false when credit_allowed is zero" do
        payment.stub(:credit_allowed => 0)
        qp.can_credit?(payment).should be_false
      end

      (PAYMENT_STATES - ['completed']).each do |state|
        it "should be false if payment state is #{state}" do
          payment.stub :state => state
          qp.can_credit?(payment).should be_false
        end
      end

    end

    context "#can_void?" do
      (PAYMENT_STATES - ['void']).each do |state|
        it "should be true if payment state is #{state}" do
          payment.stub :state => state
          payment.stub :void? => false
          qp.can_void?(payment).should be_true
        end
      end

      it "should be valse if payment state is void" do
        payment.stub :state => 'void'
        qp.can_void?(payment).should be_false
      end
    end
  end

  context "when transaction is less than 12 hours old" do
    let(:payment) { mock_model(Payment, :state => 'completed') }

    context "#can_void?" do
      (PAYMENT_STATES - ['void']).each do |state|
        it "should be true if payment state is #{state}" do
          payment.stub :state => state
          qp.can_void?(payment).should be_true
        end
      end

      it "should be false if payment state is void" do
        payment.stub :state => 'void'
        qp.can_void?(payment).should be_false
      end

    end
  end

  let(:valid_qp_attributes) { {:number => '9210073447'} }
  context "#valid?" do
    it "should validate presence of number" do
      @qp.attributes = valid_qp_attributes.except(:number)
      @qp.should_not be_valid
      @qp.errors[:number].should == ["can't be blank"]
    end

    it "should only validate on create" do
      @qp.attributes = valid_qp_attributes
      @qp.save
      @qp = QiwiPayment.find(@qp.id)
      @qp.should be_valid
    end
  end

  context "#save" do
    before do
      @qp.attributes = valid_qp_attributes
      @qp.save
      @qp = QiwiPayment.find(@qp.id)
    end
  end

end

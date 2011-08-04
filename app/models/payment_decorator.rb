Payment.class_eval do
   scope :from_qiwi, where(:source_type => 'QiwiPayment')
end

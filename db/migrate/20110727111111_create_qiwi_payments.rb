class CreateQiwiPayments < ActiveRecord::Migration
  def self.up
    create_table :qiwi_payments do |t|
      t.string :number, :null => false
    end
  end

  def self.down
  end
end

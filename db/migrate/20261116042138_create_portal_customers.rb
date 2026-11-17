class CreatePortalCustomers < ActiveRecord::Migration[8.0]
  def change
    create_table :portal_customers do |t|
      t.references :account, null: false
      t.references :contact, null: false, index: { unique: true }
      t.string :password_digest
      t.string :locale, null: false, default: 'en'
      t.integer :status, null: false, default: 0
      t.integer :session_version, null: false, default: 0

      t.timestamps
    end
  end
end

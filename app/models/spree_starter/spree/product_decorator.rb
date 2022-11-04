Spree::Product.class_eval do
  enum payment_type: { single: 0, subscription: 1, membership: 2 }

  validates :payment_type, presence: true
  validates :one_time_fee, presence: true, unless: :subscription?
  validates :form_link, presence: true, if: :membership?

  has_many :prices, through: :master, source: :prices

  def requires_shipping_category?
    false
  end
end

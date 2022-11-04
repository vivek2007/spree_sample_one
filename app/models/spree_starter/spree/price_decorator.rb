Spree::Price.class_eval do
  enum interval: { monthly: 0, quarterly: 1, yearly: 2 }
end

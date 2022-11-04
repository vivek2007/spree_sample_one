class Api::V2::ProductsController < Spree::Api::V2::Platform::ResourceController
  skip_before_action :validate_token_client

  Stripe.api_key = ENV.fetch('STRIPE_API_KEY')

  def get_product
    begin
      @product = Spree::Product.find(params[:id])
      render_serialized_payload { serialize_resource(@product) }
      return
    rescue => e
      render_error_payload(e.message)
      return
    end
  end

  def create
    @product = model_class.new(permitted_resource_params)
    ensure_current_store(@product)

    prices_params = params[:product][:prices] rescue nil
    unless @product.single?
      if !prices_params.present? || !prices_params[:monthly].present? ||
        !prices_params[:quarterly].present? || !prices_params[:yearly].present?

        @product.errors.add(:base, "All monthly, quarterly and yearly prices are required")
        render_error_payload(@product.errors)
        return
      end
    end

    if @product.save
      @product.master.prices.destroy_all if @product.master.prices.present?

      begin
        if stipe_product = Stripe::Product.create({ name: @product.name, description: @product.description })
          @product.update(stripe_product_id: stipe_product.id)
          if @product.single?
            begin
              single_price = @product.master.prices.create(amount: @product.one_time_fee)

              stripe_single_price = Stripe::Price.create({
                unit_amount: (@product.one_time_fee * 100).to_i,
                currency: @product.currency,
                product: stipe_product.id,
              })

              single_price.update(stripe_price_id: stripe_single_price.id) if stripe_single_price
            rescue => e
              remove_product_and_redirect("Unable to create product on stripe!")
              return
            end
          end
        else
          remove_product_and_redirect("Unable to create product on stripe!")
          return
        end
      rescue => e
        remove_product_and_redirect("Unable to create product on stripe! #{e.message}")
        return
      end

      unless @product.single?
        prices_params.each do |interval, amount|
          price = @product.master.prices.create(interval: interval.to_s, amount: amount)
          begin
            if  stripe_price = Stripe::Price.create({
                  unit_amount: (amount * 100).to_i,
                  currency: @product.currency,
                  recurring: recurring_hash(interval),
                  product: stipe_product.id,
                })

              price.update(stripe_price_id: stripe_price.id)
            else
              remove_product_and_redirect("Unable to create price on stripe!")
              return
            end
          rescue => e
            remove_product_and_redirect("Unable to create price on stripe! #{e.message}")
            return
          end
        end
      end

      render_serialized_payload(201) { serialize_resource(@product) }
    else
      render_error_payload(@product.errors)
    end
  end

  def update
    @product = resource
    product_params = params[:product] rescue {}
    prices_params = product_params[:prices] rescue {}

    if product_params.present? && @product.payment_type != product_params[:payment_type] && (product_params[:payment_type].eql?('subscription') || product_params[:payment_type].eql?('membership'))
      if !prices_params.present? || !prices_params[:monthly].present? ||
        !prices_params[:quarterly].present? || !prices_params[:yearly].present?

        @product.errors.add(:base, "All monthly, quarterly and yearly prices are required")
        render_error_payload(@product.errors)
        return
      end
    end

    if @product.update(permitted_resource_params)
      ensure_current_store(@product)

      if prices_params.present?
        @product.prices.each do |spree_price|
          Stripe::Price.update(
            spree_price.stripe_price_id,
            { active: false },
          )
        end
      end

      stipe_product = Stripe::Product.update(@product.stripe_product_id, { name: @product.name, description: @product.description })
      @product.update(stripe_product_id: stipe_product.id)

      if prices_params.present?
        @product.master.prices.destroy_all if @product.master.prices.present?

        if @product.single?
          single_price = @product.master.prices.create(amount: @product.one_time_fee)

          stripe_single_price = Stripe::Price.create({
            unit_amount: (@product.one_time_fee * 100).to_i,
            currency: @product.currency,
            product: stipe_product.id,
          })

          single_price.update(stripe_price_id: stripe_single_price.id) if stripe_single_price
        else
          prices_params.each do |interval, amount|
            price = @product.master.prices.create(interval: interval.to_s, amount: amount)

            stripe_price = Stripe::Price.create({
              unit_amount: (amount * 100).to_i,
              currency: @product.currency,
              recurring: recurring_hash(interval),
              product: stipe_product.id,
            })

            price.update(stripe_price_id: stripe_price.id)
          end
        end
      end

      render_serialized_payload { serialize_resource(@product.reload) }
    else
      render_error_payload(@product.errors)
    end
  end

  protected

    def model_class
      Spree::Product
    end

  private

    def authorize_spree_user
      return if spree_current_user.nil?

      case action_name
      when 'create'
        spree_authorize! :create, model_class
      end
    end

    def create_prices
      price_params = params[:product][:prices]

    end

    def remove_product_and_redirect(message)
      @product.destroy
      render_error_payload(message)
    end

    def recurring_hash(interval)
      recurring_hash = {}

      case interval
      when "monthly"
        recurring_hash = { interval: 'month' }
      when "quarterly"
        recurring_hash = { interval: 'month', interval_count: 3 }
      else
        recurring_hash = { interval: 'year' }
      end

      recurring_hash
    end
end

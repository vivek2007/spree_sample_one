class Api::V2::MultiTenantsController < ActionController::API
  def show; end

  def update; end

  def destroy; end

  def create
    if params[:db_name].blank?
        puts %q{You must supply db_name"}
    elsif params[:token] != "G0@SO15W"
        puts %q{You must supply valid token"}
    else
        db_name = params[:db_name]
        admin_mail = params[:admin_mail]
        password = params[:password]
        oauth_id = params[:oauthId]
        oauth_secret = params[:oauthSecret]
        sub_domain = params[:subdomain]
        webhook_url = params[:webhook_url]

            #convert name to postgres friendly name
        db_name.gsub!('-','_')

        initializer = SpreeShared::TenantInitializer.new(db_name)
        puts "Creating database: #{db_name}"
        initializer.create_database

            # puts "Loading seeds & sample data into database: #{db_name}"
        Apartment::Tenant.switch(db_name) do
          Rails.application.load_tasks
          Spree::Core::Engine.load_seed if defined?(Spree::Core)
        end


        begin
          admin = create_admin(db_name, admin_mail, password, oauth_id, oauth_secret, sub_domain,webhook_url)
          puts "Admin created successfully"

          render json: admin
        rescue Exception => e
          puts e.message
          render e
        end
          puts "Bootstrap completed successfully"

        end
    end

    def get_user
      if params[:db_name].blank?
        puts %q{You must supply db_name"}
      elsif params[:token] != "G0@SO15W"
        puts %q{You must supply valid token"}
      else
        db_name = params[:db_name]
        Apartment::Tenant.switch(db_name) do
          email = params[:email]

          user = Spree::User.find_by_email(email)
          puts user
          render json: user
        end
      end
    end

    def create_new_admin_user
      if params[:db_name].blank?
        puts %q{You must supply db_name"}
      elsif params[:token] != "G0@SO15W"
        puts %q{You must supply valid token"}
      else
        db_name = params[:db_name]
        admin_mail = params[:admin_mail]
        password = params[:password]
        Apartment::Tenant.switch(db_name) do
          admin = Spree::User.create(:password => password,
                                :password_confirmation => password,
                                :email => admin_mail,
                                :login => password)
          admin.generate_spree_api_key!
          puts admin
          role = Spree::Role.find_by_name "admin"
          puts role
          admin.save

          roleUser = Spree::RoleUser.create(:role => role, :user => admin)
          roleUser.save
        end
      end
    end

  def create_new_user
    if params[:db_name].blank?
      puts %q{You must supply db_name"}
    elsif params[:token] != "G0@SO15W"
      puts %q{You must supply valid token"}
    else
      db_name = params[:db_name]
      username = params[:username]
      password = params[:password]
      Apartment::Tenant.switch(db_name) do
        user = Spree::User.create(:password => password,
                                   :password_confirmation => password,
                                   :email => username,
                                   :login => password)
        user.generate_spree_api_key!
        user.save

      end
    end
  end

  def create_new_carejourney
    if params[:db_name].blank?
      puts %q{You must supply db_name"}
    elsif params[:token] != "G0@SO15W"
      puts %q{You must supply valid token"}
    else
      db_name = params[:db_name]
      product_key = params[:product]

      product = product_key[:product]
      product_name = product[:name]
      description = product[:description]
      shipping_category_id = product[:shipping_category_id]
      available_on = product[:available_on]
      price = product[:price]
      compare_at_price = product[:compare_at_price]

      Apartment::Tenant.switch(db_name) do

        product_carejourney = Spree::Product.new(description: description,
                                                 name: product_name,
                                                 available_on: available_on,
                                                 shipping_category_id: shipping_category_id,
                                                 price: price,
                                                 compare_at_price: compare_at_price,
                                                 stores: Spree::Store.all,
                                                 taxons: [Spree::Taxon.find_by_name("Care Journeys")])
        product_carejourney.save

        variants_carejourney = Spree::Variant.find_by!(product_id: product_carejourney[:id])


        stock_carejourney = Spree::StockItem.new(backorderable: true,
                                                 count_on_hand: 100,
                                                 stock_location_id: 1,
                                                 variant_id: variants_carejourney[:id])
        stock_carejourney.save

        render json: product_carejourney
      end
    end
  end

  def create_new_product
    if params[:db_name].blank?
      puts %q{You must supply db_name"}
    elsif params[:token] != "G0@SO15W"
      puts %q{You must supply valid token"}
    else
      db_name = params[:db_name]
      product_key = params[:product]

      product = product_key[:product]
      product_name = product[:name]
      description = product[:description]
      shipping_category_id = product[:shipping_category_id]
      available_on = product[:available_on]
      price = product[:price]
      compare_at_price = product[:compare_at_price]
      taxon_type = product[:taxon_type]

      Apartment::Tenant.switch(db_name) do

        product_products = Spree::Product.new(description: description,
                                          name: product_name,
                                          available_on: available_on,
                                          shipping_category_id: shipping_category_id,
                                          price: price,
                                          compare_at_price: compare_at_price,
                                          stores: Spree::Store.all,
                                          taxons: [Spree::Taxon.find_by_name(taxon_type)])
        product_products.save

        variants_products = Spree::Variant.find_by!(product_id: product_products[:id])


        stock_products = Spree::StockItem.new(backorderable: true,
                                     count_on_hand: 100,
                                     stock_location_id: 1,
                                     variant_id: variants_products[:id])
        stock_products.save

        render json: product_products
      end
    end
  end


private

def create_admin(db_name, admin_mail, password, oauth_id, oauth_secret, sub_domain, webhook_url)
  Apartment::Tenant.switch(db_name) do

    unless Spree::User.find_by_email(admin_mail)
      admin = Spree::User.create(:password => password,
                          :password_confirmation => password,
                          :email => admin_mail,
                          :login => password)

      admin.generate_spree_api_key!
      puts admin
      role = Spree::Role.find_by_name "admin"
      puts role
      admin.save

      roleUser = Spree::RoleUser.create(:role => role, :user => admin)
      roleUser.save


      url = db_name+"."+sub_domain
      puts url


      store_sql_delete = "delete from spree_stores;"
      store_sql_delete_array = ActiveRecord::Base.connection.execute(store_sql_delete)
      puts store_sql_delete_array

      Spree::Store.new do |s|
        s.name                         = 'Default'
        s.code                         = 'spree'
        s.url                          = url
        s.mail_from_address            = admin_mail
        s.customer_support_email       = admin_mail
        s.default_currency             = 'USD'
        s.default_country_id           = Spree::Config[:default_country_id]
        s.default_locale               = I18n.locale
        s.default                      = true
      end.save!

      store = Spree::Store.find_by_name "Default"

      taxonomies = Spree::Taxonomy.new(name: 'Products', store: store)
      taxonomies.save
      puts taxonomies

      taxons = Spree::Taxon.new(name: 'Products', taxonomy_id: 1)
      taxons.save
      puts taxons

      taxonomies = Spree::Taxonomy.new(name: 'Services', store: store)
      taxonomies.save
      puts taxonomies

      taxons = Spree::Taxon.new(name: 'Services', taxonomy_id: 2)
      taxons.save
      puts taxons

      taxonomies = Spree::Taxonomy.new(name: 'Care Journeys', store: store)
      taxonomies.save
      puts taxonomies

      taxons = Spree::Taxon.new(name: 'Care Journeys', taxonomy_id: 3)
      taxons.save
      puts taxons



      check_paymemt_method = Spree::PaymentMethod::Check.where(
        name: 'Pay Later',
        description: 'Pay Later.',
        active: true
      ).first_or_initialize

      check_paymemt_method.stores = Spree::Store.all
      check_paymemt_method.save!

      begin
        north_america = Spree::Zone.find_by!(name: 'North America')
      rescue ActiveRecord::RecordNotFound
        puts 'Couldn\'t find \'North America\' zone. Did you run `rake db:seed` first?'
        puts 'That task will set up the countries, states and zones required for Spree.'
        exit
      end
      shipping_category = Spree::ShippingCategory.find_or_create_by!(name: 'Default')

      shipping_methods = [
        {
          name: 'Default',
          zones: [north_america],
          display_on: 'both',
          shipping_categories: [shipping_category]
        }
      ]

      shipping_methods.each do |attributes|
        Spree::ShippingMethod.where(name: attributes[:name]).first_or_create! do |shipping_method|
          shipping_method.calculator = Spree::Calculator::Shipping::FlatRate.create!
          shipping_method.zones = attributes[:zones]
          shipping_method.display_on = attributes[:display_on]
          shipping_method.shipping_categories = attributes[:shipping_categories]
        end
      end

      webhook = Spree::Webhooks::Subscriber.create(:url => webhook_url,
                                         :active => true,
                                         :subscriptions => '["order.placed"]')
      webhook.save
      puts webhook

      #TODO: replace with auto-generated oauth applications
      oauthApplication = Spree::OauthApplication.create(:uid => oauth_id,
        :secret => oauth_secret, :redirect_uri => '', :name => 'Admin Panel', :scopes => 'admin')
      oauthApplication.save
      puts oauthApplication

      return admin

    end
  end
end

end

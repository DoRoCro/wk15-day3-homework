#!/bin/sh
# create new app folder using postgreSQL database instead of SQLite default
#rails new show_api -d postgresql

# using SQLite3
rails new show_api

cd show_api
git init
git add .
git commit -m '"setup outline rails show_api app"'

echo "adding awesome_print"

awk 'NR==2{print; print "gem '"'"'awesome_print'"'"'"; print "gem '"'"'responders'"'"'"; print "gem '"'"'devise'"'"'" } NR!=2'  Gemfile > tmp.tmp
mv tmp.tmp Gemfile
bundle

# create database, fails if already defined
rake db:create

echo "generating model..."
rails generate model Show title:string series:integer description:text image:string programmeID:string
rails g model User name:string password:string
rails g model Favourite show:references user:references comment:text rating:integer


echo "making seeds"

cat - <<EOF >> db/seeds.rb
Favourite.delete_all
User.delete_all
Show.delete_all

show1 = Show.create(
  {
    "title": "The Great British Bake Off",
    "series": 7,
    "description": "Master bakers Mary & Paul and the incomparable presenting duo of Mel & Sue are back for another interesting series about baking cakes.",
    "image": "placeholder.jpg",
    "programmeID": "b013pqnm" 
  }
)
show2 = Show.create(
  {
    "title": "Line of Duty",
    "series": 4,
    "description": "While Nick Huntley faces lengthy questioning, AC-12 remain convinced of Roz's involvement.",
    "image": "https://ichef.bbci.co.uk/images/ic/192x108/p051234x.jpg",
    "programmeID": "b08plvy6" 
  }
)
show3 = Show.create(
  {
    "title": "Line of Duty",
    "series": 4,
    "description": "DCI Roz Huntley struggles to allay her husband's suspicions. AC-12 find a new angle to pursue their case against her.",
    "image": "https://ichef.bbci.co.uk/images/ic/192x108/p050dszh.jpg",
    "programmeID": "b08nwx5r" 
  }
)
show4 = Show.create(
  {
    "title": "Britain's Nuclear Bomb: The Inside Story",
    "series": 1,
    "description": "In 1957, Britain exploded its first megaton hydrogen bomb - codenamed Operation Grapple X. It was the culmination of an extraordinary scientific project, which against almost insuperable odds turned Britain into a nuclear superpower. This is the inside story of how Britain got 'the bomb'.",
    "image": "https://ichef.bbci.co.uk/images/ic/640x360/p0517mkn.jpg",
    "programmeID": "b08nz0xh" 
  }
)

u1 = User.create({
  name: 'Yossarian',
  password: 'opensesame'
})

u2 = User.create({
  name: 'Milo Minderbinder',
  password: "entrepreneur"
})

fav1 = Favourite.create({
  user: u1,
  show: show1,
  comment: "This was nice and relaxing",
  rating: 5
})

fav2 = Favourite.create({
  user: u1,
  show: show2,
  comment: "I didn't expect that",
  rating: 4
})

fav21 = Favourite.create({
  user: u2,
  show: show4,
  comment: "That gives me a business idea",
  rating: 3
})
EOF




# setup relations
awk 'NR==1{print; print "   has_many :favourites"} NR!=1' app/models/user.rb > tmp.tmp
awk 'NR==2{print; print "   has_many :favourite_shows, through: :favourites, source: :show"} NR!=2' tmp.tmp > app/models/user.rb

awk 'NR==1{print; print "   has_many :favourites"} NR!=1' app/models/show.rb > tmp.tmp
awk 'NR==2{print; print "   has_many :favourited_by, through: :favourites, source: :user"} NR!=2' tmp.tmp > app/models/show.rb


# make the modifications to the database model
rake db:migrate

# load the seeds into the database
rake db:seed

echo "Database setup, moving to routes setup"

# setup default routes, replacing existing default file routes.rb

mv config/routes.rb config/routes.rb.orig
cat - <<EOF > config/routes.rb
Rails.application.routes.draw do
  
  scope path: 'api' do  
    resources :shows
  end

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
EOF

echo "routes file replaced"
# add shows_controller.rb into controllers

cat - <<EOF > app/controllers/shows_controller.rb
class ShowsController < ApplicationController
  
  before_action :authenticate_user!

  def show_params
    params.require(:show).permit([:title, :series, :description, :image, :programmeID])
  end

  def index 
    shows = Show.all
    render :json => shows
  end

  def show
    show = Show.find(params[:id])
    render json: show
  end

  def create
    show = Show.create(show_params)
    render json: show
  end

end
EOF

echo "shows_controller.rb added"

# echo "  protect_from_forgery with: :null_session"
# echo "in controllers/application_controller.rb to allow updates via API"
# awk '{gsub(/:exception/,":null_session")}'  app/controller/applications_controller.rb > tmp.tmp
# mv tmp.tmp app/controller/applications_controller.rb
sed -i '.orig' 's/exception/null_session/' app/controllers/application_controller.rb
echo "application_controller.rb edited"
cat app/controllers/application_controller.rb


echo "Now adding authentication by removing User and replacing with 'devise' based user"
rails generate migration drop_users

# need to edit migration file created
cd db/migrate
filename=$(ls -t1 | grep "drop_users" )

echo "editing db/migrate/$filename"

awk 'NR==2{print; print "    drop_table :users" } NR!=2'  $filename > tmp.tmp
mv tmp.tmp $filename
cd ../..
pwd


echo "implement migrate and destroy User"
rake db:migrate
rails destroy model User
rake db:migrate


# devise already added above in Gemfile changes
bundle install
rails generate devise:install
rails generate devise User
rake db:migrate

pwd
# ls app/controllers - not found, has not been created yet...
# # at the top of users_controller.rb
# mv app/controllers/users_controller.rb app/controllers/users_controller.rb.orig
# awk 'NR==2{print; print ""; print "  before_action :authenticate_user!"; print ""} NR!=2'  app/controllers/users_controller.rb.orig > app/controllers/users_controller.rb
# echo "edited app/controllers/users_controller.rb: "
# cat app/controllers/users_controller.rb

echo "set up rack-cors"
gem install rack-cors

awk 'NR==2{print; print "gem '"'"'rack-cors'"'"', :require => '"'"'rack/cors'"'"'"} NR!=2'  Gemfile > tmp.tmp
mv tmp.tmp Gemfile
echo "Bundle!!!"
bundle

cat - <<EOF >> config/application.rb
module ShowsApi
  class Application < Rails::Application

    config.middleware.insert_before 0, "Rack::Cors" do
      allow do
        origins '*'
        resource '*', :headers => :any, :methods => [:get, :post, :options, :delete]
      end
    end

    config.active_record.raise_in_transactional_callbacks = true
  end
end
EOF

echo "updating config.ru"
mv config.ru config.ru.orig

cat - <<EOF > config.ru
use Rack::Cors do
  allow do
    origins 'localhost:3000', '127.0.0.1:3000',
            /\Ahttp:\/\/192\.168\.0\.\d{1,3}(:\d+)?\z/
            # regular expressions can be used here

    resource '/file/list_all/', :headers => 'x-domain-token'
    resource '/file/at/*',
        :methods => [:get, :post, :delete, :put, :patch, :options, :head],
        :headers => 'x-domain-token',
        :expose  => ['Some-Custom-Response-Header'],
        :max_age => 600
        # headers to expose
  end

  allow do
    origins '*'
    resource '/public/*', :headers => :any, :methods => :get
  end
end

require ::File.expand_path('../config/environment', __FILE__)
run Rails.application

use Rack::Cors do

  allow do
    origins '*'
    resource '/public/*', :headers => :any, :methods => :get
  end
end
EOF

cat - <<EOF >> app/controllers/users_controller.rb
class UsersController < ApplicationController
  before_action :authenticate_user!
  def index
    render json: current_user
  end
end
EOF

cat - <<EOF >> app/controllers/registrations_controller.rb
class RegistrationsController < Devise::RegistrationsController  
    respond_to :json
end 
EOF

cat - <<EOF >> app/controllers/sessions_controller.rb
class SessionsController < Devise::SessionsController  
    respond_to :json
end
EOF

echo "add
devise_for :users, :controllers => {sessions: 'sessions', registrations: 'registrations'}
resources :users"

mv config/routes.rb config/routes.rb.pre
# devise_for :users already present on line 3, so want to replace that line and not re-echo it

awk 'NR==3{ print "  devise_for :users, :controllers => { sessions: '"'"'sessions'"'"', registrations: '"'"'registrations'"'}"'"; print "  resources :users"} NR!=3' config/routes.rb.pre > config/routes.rb




echo
echo '"rails s" to start server'

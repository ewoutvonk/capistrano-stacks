# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.
# Copyright 2006-2008 by Mike Bailey. All rights reserved.

Capistrano::Configuration.instance(:must_exist).load do 

  framework :rails3 do

    require 'bundler/capistrano'

    namespace :deploy do
  
      task :migrate, :roles => :db, :only => { :primary => true } do
        migrate_env = fetch(:migrate_env, "")
        migrate_target = fetch(:migrate_target, :latest)

        directory = case migrate_target.to_sym
          when :current then current_path
          when :latest  then latest_release
          else raise ArgumentError, "unknown migration target #{migrate_target.inspect}"
          end

        run "cd #{directory} && #{rake} RAILS_ENV=#{rails_env} #{migrate_env} db:migrate"
      end

      namespace :db do

        desc "Create database"
        task :create, :roles => :app do
          run "cd #{latest_release} && rake db:create RAILS_ENV=#{rails_env}"
        end

        desc "Run database migrations"
        task :migrate, :roles => :app do
          run "cd #{latest_release} && rake db:migrate RAILS_ENV=#{rails_env}"
        end
      
        desc "Run database migrations"
        task :schema_load, :roles => :app do
          run "cd #{latest_release} && rake db:schema:load RAILS_ENV=#{rails_env}"
        end

        desc "Roll database back to previous migration"
        task :rollback, :roles => :app do
          run "cd #{latest_release} && rake db:rollback RAILS_ENV=#{rails_env}"
        end
      
      end
  
    end
    
  end
  
end

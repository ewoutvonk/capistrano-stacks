# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.
# Copyright 2006-2008 by Mike Bailey. All rights reserved.

Capistrano::Configuration.instance(:must_exist).load do 

  dbserver :mysql do

    set :mysql_admin_user, 'root'
    set(:mysql_admin_pass) { Capistrano::CLI.password_prompt "Enter database password for '#{mysql_admin_user}':"}

    after 'deploy:setup', 'deploy:stacks:after_deploy_setup_handlers:create_database_and_grant_user'

    namespace :deploy do
    
      namespace :stacks do
        namespace :after_deploy_setup_handlers do
        
          task :create_database_and_grant_user, :roles => :db do
            unless roles[:db].servers.empty?

              stage = exists?(:stage) ? fetch(:stage).to_s : ''
              db_config_file = File.join('config', stage, 'database.yml')
              
              if File.exists?(db_config_file)
              
                db_config = YAML.load_file(db_config_file)
                
                unless db_config[rails_env].nil? || (!db_config[rails_env]["host"].nil? && !db_config[rails_env]["host"].empty? && ![ "localhost", "127.0.0.1" ].include?(db_config[rails_env]["host"]))
                
                  set :db_user, db_config[rails_env]["username"]
                  set :db_password, db_config[rails_env]["password"]
                  set(:mysql_admin_pass_option) { (mysql_admin_pass.nil? || mysql_admin_pass.empty?) ? "" : "-p" }
                  set :db_name, db_config[rails_env]["database"]

                  if db_user && db_name

                    cmd = "CREATE DATABASE IF NOT EXISTS #{db_name}"
                    run "mysql -u #{mysql_admin_user} #{mysql_admin_pass_option} -e '#{cmd}'" do |channel, stream, data|
                      if data =~ /^Enter password:/
                         channel.send_data "#{mysql_admin_pass}\n"
                       end
                    end       

                    cmd = "GRANT ALL PRIVILEGES ON #{db_name}.* TO '#{db_user}'@localhost IDENTIFIED BY '#{db_password}';"
                    run "mysql -u #{mysql_admin_user} #{mysql_admin_pass_option} #{db_name} -e \"#{cmd}\"" do |channel, stream, data|
                      if data =~ /^Enter password:/
                         channel.send_data "#{mysql_admin_pass}\n"
                       end
                    end
                  
                  end
                  
                end
                
              end
                
            end
          end
        
        end
      end
    
    end
    
  end
    
end

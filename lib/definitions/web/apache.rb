# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.
# Copyright 2006-2008 by Mike Bailey. All rights reserved.

Capistrano::Configuration.instance(:must_exist).load do 

  webserver :apache2 do
    
    set :apache_sites_available_dir, '/etc/apache2/sites-available'

    after 'deploy:stacks:after_deploy_setup_handlers:upload_configurations', 'deploy:stacks:after_deploy_setup_handlers:activate_in_apache'

    namespace :deploy do

      namespace :stacks do
        namespace :after_deploy_setup_handlers do

          task :activate_in_apache do
            sudo "ln -sf #{deploy_to}/capistrano/apache_vhost #{apache_sites_available_dir}/#{application}"
            sudo "a2ensite #{application}"
          end

        end
      end

    end

  end

end

# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.
# Copyright 2006-2008 by Mike Bailey. All rights reserved.

Capistrano::Configuration.instance(:must_exist).load do 
  
  stack :passenger, :rails3 do
  
    before 'deploy:symlink', 'deploy:stacks:before_deploy_symlink_handlers:set_owner_of_environment_rb'
  
    namespace :deploy do
      namespace :stacks do
        namespace :before_deploy_symlink_handlers do
        
          task :set_owner_of_environment_rb do
            sudo "chown #{user} #{latest_release}/config/environment.rb"
            sudo "chgrp #{group} #{latest_release}/config/environment.rb" if exists?(:group)
          end
        
        end        
      end
    end
    
  end
  
end

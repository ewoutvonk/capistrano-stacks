# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.

Capistrano::Configuration.instance(:must_exist).load do 

  appserver :passenger do

    namespace :deploy do
  
      task :restart, :roles => :app, :except => { :no_release => true } do
        run "touch #{current_path}/tmp/restart.txt"
      end

    end

  end
  
end

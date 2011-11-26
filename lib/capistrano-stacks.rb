# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.
# Copyright 2006-2008 by Mike Bailey. All rights reserved.

# prevent loading when called by Bundler, only load when called by capistrano
if caller.any? { |callstack_line| callstack_line =~ /^Capfile:/ }
  unless Capistrano::Configuration.respond_to?(:instance)
    abort "capistrano-stacks requires Capistrano 2"
  end

  require 'erb'

  module Capistrano
    module Configuration
      class Stack

        class << self

          def components
            @@components ||= {}
          end

          def activated_stacks
            @@activated_stacks ||= []
          end

          def activated_stack_components
            @@activated_stack_components ||= {}
          end

          def activations
            activated_stack_components.map { |k,v| v }.flatten + activated_stacks
          end

          def define(*args, &block)
            ident = stack_name(*args)
            all[ident] = block
          end

          def activate_stack_component(stack_component, _ident)
            activated_stack_components[stack_component] ||= []
            unless activated_stack_components[stack_component].include?(_ident)
              activated_stack_components[stack_component] << _ident
              (1..(activated_stack_components[stack_component].length)).to_a.each do |n|
                args_array = activated_stack_components[stack_component].permutation(n).to_a.map(&:sort).uniq
                args_array.each do |args|
                  activate_stack(*args)
                end
              end
            end
          end

          private

          def all
            @@all ||= {}
          end

          def activate_stack(*args)
            ident = stack_name(*args)
            unless activated_stacks.include?(ident) && all[ident].is_a?(Proc)
              all[ident].call
              activated_stacks << ident
            end
          end

          def stack_name(*args)
            "_#{args.map(&:to_s).sort.join('_')}_".to_sym
          end

        end

      end

      class StackComponent

        def pending_activations
          @pending_activations ||= []
        end

        def component_name
          self.class.name.gsub(/^Capistrano::Configuration::/, '').gsub(/^StackComponent::/, '').downcase.to_sym
        end

        def define(_ident, &block)
          ident = stack_component_name(_ident)
          all[ident] = block
          if pending_activations.include?(ident)
            pending_activations.delete(ident)
            activate(_ident)
          end
        end

        def activate(_ident)
          ident = stack_component_name(_ident)
          if all[ident].nil?
            pending_activations << ident
          else
            all[ident].call if all[ident].is_a?(Proc)
            Capistrano::Configuration::Stack.activate_stack_component(self.component_name, ident)
          end
        end

        private

        def all
          @all ||= {}
        end

        def stack_component_name(_ident)
          _ident.to_sym
        end

      end
    end
  end

  Capistrano::Configuration.instance(:must_exist).load do

    def stack(*args, &block)
      if block_given?
        Capistrano::Configuration::Stack.define(*args, &block)
      else
        Capistrano::Configuration::Stack.activate(*args)
      end
    end

    def stack_component(klass, _ident, &block)
      component_class_instance = Capistrano::Configuration::Stack.components[klass.component_name]
      if block_given?
        component_class_instance.define(_ident, &block)
      else
        component_class_instance.activate(_ident)
      end
    end

    def define_stack_component_type(type_name)
      klass_name = "Capistrano::Configuration::StackComponent::#{type_name.to_s.downcase.gsub(/^./, &:upcase)}"
      # create CapistranoXyz class, with superclass CapistranoStackComponent
      Object.const_set(klass_name, Class.new(Capistrano::Configuration::StackComponent))
      klass = Object.const_get(klass_name)
      Capistrano::Configuration::Stack.components[klass.component_name] = klass.new
      method_name = klass.component_name
      query_method_name = "#{method_name}?".to_sym
      list_method_name = "#{method_name}s".to_sym
      # define method xyz with two parameters:
      # - _ident : name of the xyz definition (i.e. if xyz is dbserver, and _ident is :mysql)
      # - &block : the block which defines the capistrano extensions in question
      # this method in turn calls stack_component
      # variable_name is the capistrano variable in which the selection is stored.
      define_method(method_name) do |_ident, &block|
        stack_component(klass, _ident, &block)
      end
      # define method xyz? with one parameter
      # - _ident : name of the xyz definition (i.e. if xyz is dbserver, and _ident is :mysql)
      # this method checks whether something is activated by the name set in _ident
      # (i.e. 'dbserver?(:mysql)' returns true if mysql has been activated as the db server)
      define_method(query_method_name) do |_ident|      
        Capistrano::Configuration::Stack.activated_stack_components[klass.component_name].is_a?(Array) &&
          Capistrano::Configuration::Stack.activated_stack_components[klass.component_name].include?(_ident.to_sym)
      end
      # define method xyzs with zero parameters
      # this method returns all activations for the xyz definition
      # (i.e. 'dbservers' returns '[:mysql, :sqlite3]' if these two were activated as dbservers)
      define_method(list_method_name) do
        Capistrano::Configuration::Stack.activated_stack_components[klass.component_name] || []
      end
    end

    define_stack_component_type :framework
    define_stack_component_type :dbserver
    define_stack_component_type :webserver
    define_stack_component_type :appserver

    after 'deploy:setup', 'deploy:stacks:after_deploy_setup_handlers:upload_configurations'
    before 'deploy:symlink', 'deploy:stacks:before_deploy_symlink_handlers:upload_configurations'

    namespace :deploy do
      namespace :stacks do
        namespace :after_deploy_setup_handlers do

          task :upload_configurations, :except => { :no_release => true } do
            Capistrano::Configuration::Stack.activations.map do |ident|
              dir = "#{File.dirname(__FILE__)}/templates/#{ident}"
              File.directory?(dir) ? dir : nil
            end.compact.each do |dir|
              Dir.glob("#{dir}/*.erb").each do |config_file|
                config_file_name = File.basename(config_file)
                path = File.join(deploy_to, 'capistrano', File.basename(config_file_name, '.erb'))

                local_template = File.join(Rails.root, 'config', 'templates', 'capistrano', config_file_name)
                if File.exists?(local_template)
                  template = ERB.new(IO.read(local_template), nil, '-')
                else
                  template = ERB.new(IO.read(config_file), nil, '-')
                end
                rendered_template = template.result(binding)

                run "test -d #{File.dirname(path)} || mkdir #{File.dirname(path)}"
                put rendered_template, path, :mode => 0644
              end
            end
          end

        end

        namespace :before_deploy_symlink_handlers do

          task :upload_configurations do
            if exists?(:stage)
              globs = { :per_role => "#{Rails.root}/config/#{stage}/*/*",
                        :base => "#{Rails.root}/config/#{stage}/*" }

              globs.each do |type, glob|
                Dir.glob(glob).each do |config_file|
                  relative_file_name = if type == :per_role
                    File.join(File.basename(File.dirname(config_file)), File.basename(config_file))
                  else
                    File.basename(config_file)
                  end

                  put File.read(config_file), "#{shared_path}/#{relative_file_name}", :mode => 0600
                end
              end
            end
          end

        end

      end
    end

  end

  Dir.glob("#{File.dirname(__FILE__)}/definitions/**/*.rb").collect do |filename|
    require filename
  end  

end
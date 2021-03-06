require 'opsworks/deployment'

module OpsWorks
  module CLI
    module Subcommands
      module Recipes
        # rubocop:disable MethodLength
        # rubocop:disable CyclomaticComplexity
        def self.included(thor)
          thor.class_eval do
            desc 'recipes:run RECIPE [--stack STACK]', 'Execute a Chef recipe'
            option :stack, type: :array
            option :timeout, type: :numeric, default: 300
            define_method 'recipes:run' do |recipe|
              fetch_keychain_credentials unless env_credentials?
              stacks = parse_stacks(options.merge(active: true))
              deployments = stacks.map do |stack|
                say "Executing recipe on #{stack.name}..."
                stack.execute_recipe(recipe)
              end
              OpsWorks::Deployment.wait(deployments, options[:timeout])
              unless deployments.all?(&:success?)
                failures = []
                deployments.each_with_index do |deployment, i|
                  failures << stacks[i].name unless deployment.success?
                end
                fail "Command failed on #{failures.join(', ')}"
              end
            end

            desc 'recipes:add LAYER EVENT RECIPE [--stack STACK]',
                 'Add a recipe to a given layer and lifecycle event'
            option :stack, type: :array
            define_method 'recipes:add' do |layername, event, recipe|
              fetch_keychain_credentials unless env_credentials?
              stacks = parse_stacks(options)
              stacks.each do |stack|
                layer = stack.layers.find { |l| l.shortname == layername }
                next unless layer
                next if layer.custom_recipes[event].include?(recipe)

                say "Adding recipe to #{stack.name}."
                layer.add_custom_recipe(event, recipe)
              end
            end
          end
        end
        # rubocop:enable CyclomaticComplexity
        # rubocop:enable MethodLength
      end
    end
  end
end

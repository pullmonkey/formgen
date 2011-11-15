module Skizmo
  module Generators
    class FormGenerator < Rails::Generators::NamedBase  
      source_root File.expand_path('../templates', __FILE__)  
      argument :class_name, :type => :string, :default => "FooBar"
      class_option :javascript, :type => :boolean, :default => true, 
        :description => "Include javascript to add and remove associated attributes if there are has_many associations"
      class_option :helpers, :type => :boolean, :default => true, 
        :description => "Update helpers to add link_to_add and link_to_remove methods if there are has_many associations"
        
      def generate_form  
        unless nested_has_many_classes.empty?
          copy_file "javascript.js", "public/javascripts/jquery.add_remove_links.js" if options.javascript?  
          copy_file "helper.rb", "app/helpers/add_remove_links_helper.rb" if options.helpers?  
        end
        template "new.html.erb", "app/views/#{file_name.pluralize}/new.html.erb"  
        template "edit.html.erb", "app/views/#{file_name.pluralize}/edit.html.erb"  
        template "_form.html.erb", "app/views/#{file_name.pluralize}/_form.html.erb"  
        nested_classes_with_attributes.each do |hash_with_kls_and_attrs|
          @kls   = hash_with_kls_and_attrs[:kls]    # class object
          @sym   = hash_with_kls_and_attrs[:sym]    # passed to the fields_for
          @attrs = hash_with_kls_and_attrs[:attrs]  # attrs that are worthy for this association
          @assoc = hash_with_kls_and_attrs[:assoc]  # so we know whether to use the add and remove links or not
          template "_nested_fields.html.erb", "app/views/#{file_name.pluralize}/_#{@sym.to_s.singularize}_fields.html.erb"
        end
      end  
        
      private  

      def file_name
        class_name.underscore  
      end  

      def cls
        class_name.classify.constantize
      end

      def attributes_worth_using_in_the_form(options={})
        kls = options[:class] || cls
        rejects = ["created_at","updated_at","created_on","updated_on","id",/_id$/]
        kls.column_names.reject do |x| 
          rejects.include?(x) || !rejects.select{|y| y.is_a?(Regexp) and x =~ y}.empty?
        end
      end
     
      def attr_form_method(kls, attr)
        case kls.columns.find{|c| c.name == attr}.try(:type)
        when :string, :integer, :float, :decimal, :datetime, :timestamp, :time, :date
          # using text fields for the date selectors b/c most people will use a js calendar
          return :text_field
        when :text
          return :text_area
        when :boolean
          return :check_box
        else
          return :text_field
        end
      end
      
      def class_reflections
        cls.reflections
      end

      # TODO only get the classes that have "nested attributes"

      def nested_has_many_classes
        has_many_through_associations = class_reflections.select{|k,v| v.macro == :has_many and v.options.has_key?(:through)}
        through_assocs = has_many_through_associations.map{|x| x.last.options[:through]}
        # we don't care about the associations that primarily exist to assist the has_many :through
        has_many_associations = class_reflections.select{|k,v| v.macro == :has_many and 
                                                              not v.options.has_key?(:through) and 
                                                              not through_assocs.include?(k)}
        # these are the keys of the reflections we care about 
        (has_many_through_associations | has_many_associations).map(&:first)
      end
      
      def nested_belongs_to_classes
        class_reflections.select{|k,v| v.macro == :belongs_to}.map(&:first)
      end

      def nested_classes
        {:belongs_to => nested_belongs_to_classes, :has_many => nested_has_many_classes}
      end

      def nested_classes_with_attributes
        to_return = []
        nested_classes.each do |assoc,ncs|
          ncs.each do |nc|
            kls = nc.to_s.classify.constantize
            attrs = attributes_worth_using_in_the_form(:class => kls)
            to_return << {:sym => nc, :kls => kls, :attrs => attrs, :assoc => assoc}
          end
        end
        to_return
      end

    end  
  end
end

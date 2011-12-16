module Skizmo
  module Generators
    class FormGenerator < Rails::Generators::NamedBase  
      source_root File.expand_path('../templates', __FILE__)  
      argument :name, :type => :string
      class_option :javascript, :type => :boolean, :default => true, 
        :description => "Include javascript to add and remove associated attributes if there are has_many associations"
      class_option :helpers, :type => :boolean, :default => true, 
        :description => "Update helpers to add link_to_add and link_to_remove methods if there are has_many associations, as well as a setup method for building objects required for nested attribute associations and for building selectable lists for select boxes"
      class_option :select_boxes, :type => :boolean, :default => true, 
        :description => "Generates select box selections for belongs_to and has_many associations that are not accepted as nested_attributes"
        
      def generate_form 
        unless nested_has_many_classes.empty?
          copy_file "javascript.js", "public/javascripts/jquery.add_remove_links.js" if options.javascript?  
          copy_file "helper.rb", "app/helpers/add_remove_links_helper.rb" if options.helpers?  
        end
        unless nested_classes_with_attributes.empty?
          template "setup_helper.rb", "app/helpers/#{file_name}_setup_helper.rb" if options.helpers?  
        end
        template "new.html.#{engine}", "app/views/#{file_name.pluralize}/new.html.#{engine}"  
        template "edit.html.#{engine}", "app/views/#{file_name.pluralize}/edit.html.#{engine}"  
        @have_attachment_string = have_attachments? ? ", :html => { :multipart => true }" : ""
        template "_form.html.#{engine}", "app/views/#{file_name.pluralize}/_form.html.#{engine}"  
        nested_classes_with_attributes.each do |hash_with_kls_and_attrs|
          @kls   = hash_with_kls_and_attrs[:kls]    # class object
          @sym   = hash_with_kls_and_attrs[:sym]    # passed to the fields_for
          @attrs = hash_with_kls_and_attrs[:attrs]  # attrs that are worthy for this association
          @assoc = hash_with_kls_and_attrs[:assoc]  # so we know whether to use the add and remove links or not
          template "_nested_fields.html.#{engine}", "app/views/#{file_name.pluralize}/_#{@sym.to_s.singularize}_fields.html.#{engine}"
        end
      end  

      # TODO multi-level nesting
        
      private  

      def engine
        ::Rails.application.config.app_generators.rails[:template_engine].to_s rescue "erb"
      end

      def file_name
        cls_underscore
      end  

      def cls
        cls_classname.constantize
      end

      def cls_classname
        name.classify.to_s
      end
      
      def cls_underscore
        name.to_s.underscore 
      end

      # Base this on has_attached_file
      def attributes_worth_using_in_the_form(options={})
        kls = options[:class] || cls
        rejects = ["created_at","updated_at","created_on","updated_on","id",/_id$/]
        # consolidate x_file_name, x_content_type and x_file_size to just x
        attachment_endings = ["_file_name", "_content_type", "_file_size", "_updated_at"]
        attachments = attachments_for(kls) || []
        attachment_rejects = attachment_endings.map{|x| attachments.map{|y| y.to_s + x.to_s}}.flatten.uniq
        attrs_for_form = kls.column_names.reject do |x| 
          rejects.include?(x) || !rejects.select{|y| y.is_a?(Regexp) and x =~ y}.empty? ||
          attachment_rejects.include?(x)
        end
        attrs_for_form | attachments
      end
     
      # Base this on has_attached_file
      def attr_form_method(kls, attr)
        # consolidate x_file_name, x_content_type and x_file_size to just x and use file_field
        return :file_field if atts = attachments_for(kls) and atts.include?(attr)
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

      def attachments_for(kls)
        if kls.respond_to? :attachment_definitions and atts = kls.try(:attachment_definitions)
          return atts.keys
        else
          return nil
        end
      end
      
      def have_attachments?
        # check nested and object's own
        return true if attachments_for(cls.to_s.classify.constantize)
        (nested_has_many_classes | nested_belongs_to_classes).each do |kls|
          return true if attachments_for(kls.to_s.classify.constantize)
        end
        return false
      end

      def nested_attributes
        cls.nested_attributes_options.keys
      end

      def class_reflections
        cls.reflections
      end

      def has_many_classes
        has_many_through_associations = class_reflections.select{|k,v| v.macro == :has_many and v.options.has_key?(:through)}
        through_assocs = has_many_through_associations.map{|x| x.last.options[:through]}
        # we don't care about the associations that primarily exist to assist the has_many :through
        has_many_associations = class_reflections.select{|k,v| v.macro == :has_many and 
                                                              not v.options.has_key?(:through) and 
                                                              not through_assocs.include?(k)}
        # these are the keys of the reflections we care about 
        (has_many_through_associations | has_many_associations).map(&:first)
      end

      # only get the classes that have "nested attributes"
      def nested_has_many_classes
        has_many_classes.select{|k| nested_attributes.include?(k)}
      end
      
      def non_nested_has_many_classes
        has_many_classes.select{|k| !nested_attributes.include?(k)}
      end
      
      def belongs_to_classes
        class_reflections.select{|k,v| v.macro == :belongs_to}.map(&:first)
      end
      
      # only get the classes that have "nested attributes"
      def nested_belongs_to_classes
        belongs_to_classes.select{|k| nested_attributes.include?(k)}
      end
      
      def non_nested_belongs_to_classes
        belongs_to_classes.select{|k| !nested_attributes.include?(k)}
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

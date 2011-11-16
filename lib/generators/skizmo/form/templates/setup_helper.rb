module <%= cls_classname %>SetupHelper
  def setup_<%= cls_underscore %>(obj)
    <% nested_belongs_to_classes.each do |cls_name| -%>
    obj.build_<%= cls_name %> if obj.<%= cls_name %>.blank?
    <% end -%>
    <% nested_has_many_classes.each do |cls_name| -%>
    obj.<%= cls_name %>.build if obj.<%= cls_name %>.empty?
    <% end -%>
    return obj
  end

<% if options.select_boxes? -%>
  def build_select_list(assoc, options={})
    name  = options[:name]  || "name"
    scope = options[:scope] || "all"
    begin
      # name and id associations
      assoc.to_s.classify.constantize.send(scope).map{|a| [a.send(name), a.id]}
    rescue
      # use id for text and value
      assoc.to_s.classify.constantize.send(scope).map(&:id)
    end
  end
<% end -%>
end

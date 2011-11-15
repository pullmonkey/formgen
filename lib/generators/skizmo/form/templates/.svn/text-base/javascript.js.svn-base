function remove_fields(link) {
  jQuery(link).prev("input[type=hidden]").val("1");
  jQuery(link).closest(".fields").hide();
}

function add_fields(link, association, content) {
  var new_id = new Date().getTime();
  var regexp = new RegExp("new_" + association, "g");
  jQuery(link).parent().before(content.replace(regexp, new_id));
}

(function($) {
  $(function() {
    $.each(foswiki.jquery.button, function() {
      var options = this;
      var $this = $("#"+options.id);
      if (options.onclick) {
        $this.click(function() {
          return options.onclick.call(this);
        });
      }
    });
 });
})(jQuery);



// (c)opyright 2006-2011 Michael Daum http://michaeldaumconsulting.com

// document ready
jQuery(function($) {

  /* move revinfo */
  if (foswiki.getPreference("NatSkin.fixRevisionPosition") == 'true') {
    var target = $(".natMainContents h1:first");
    if (target.length) { 
      $(".natRevision").remove().insertAfter(target);
    }
  }

  /* horiz menu */
  if (foswiki.getPreference("NatSkin.initWebMenu") == 'true') {
    var $container = $(".natWebMenuContents");
    $container.children("ul").superfish({
      dropShadows: false, /* enabled using css3 */
      autoArrows: false,
      onBeforeShow: function() {
        var $this = $(this);
        if ($this.is(".ajaxMenu")) {
          var opts = $.extend({}, $this.metadata());
          if (opts.url) {
            $this.load(opts.url, function() {
              $this.removeClass("ajaxMenu");
              $this.parent().removeClass("hasAjaxMenu");
            });
          }
        }
      }
    })
    .find("li:has(ul)").addClass("hasSubMenu")
    .find("li:has(.ajaxMenu)").addClass("hasAjaxMenu");

    $container.removeClass('natWebMenuHidden');
    if ($.browser.msie) {
      $container.css('display', 'block');
    }
  }

  /* add overflow div for tables */
  if (foswiki.getPreference("NatSkin.initOverflows") == 'true') { 
    $(".natMainContents").find(".foswikiTable, .DISui-jqgrid")
      .not($(".foswikiTable .foswikiTable", this))
      .wrap("<div class='overflow foswikiTableOverflow'></div>");
  }

  if (foswiki.getPreference("NatSkin.initTopicActions") == 'true') { // topicaction tooltips 
    $(".natHistoryTopicActions .natTopicAction").each(function() {
      var $this = $(this),
          tip = $this.find("span.natTopicActionShortLabel").text();
      $this.attr("title", tip);
    });
  }

  // init more actions menu
  $(".natMoreActionsMenu:not(.natInitedMoreActionsMenu)").livequery(function() {
    var $this = $(this), opts = $.extend({}, $this.metadata());
    $this.addClass("natInitedMoreActionsMenu").superfish(opts);
  });

  // remove empty attachment comments
  $("#natTopicAttachments .natAttachmentComment").livequery(function(){
    var text = $(this).text();
    //alert("text='"+text+"' char="+text.charCodeAt(0));
    if ((text.length == 1 && text.charCodeAt(0) == 160)) {
      $(this).hide();
    }
  });

  $(".foswikiFormSteps").livequery(function() {
    var $this = $(this);
    $this.children(".foswikiFormStep:last").addClass("foswikiFormLast");
    $this.children(".foswikiFormStep:first").addClass("foswikiFormFirst");
  });

  if (false) { // add foswikiLast to last row of a foswikiTable/foswikiLayoutTable/foswikiNullTable
    $(".foswikiLayoutTable, .foswikiTable, .foswikiNullTable").livequery(function() {
      var $this = $(this);
      $this.find("tr:last").addClass("foswikiLast");
      $this.find("tr:first").addClass("foswikiFirst");
    });
  }

  if (foswiki.getPreference("NatSkin.initSideBar") == 'true') { // typographic improvements in sidebar
    $('.natSideBar h2 + h2:not(.jqInitedSideBar)').livequery(function() {
      var $this = $(this);
      $this.addClass('jqInitedSideBar');
      $this.replaceWith('<h3>'+$this.html()+'</h3>');
    });
  }

  if (foswiki.getPreference("NatSkin.initAutocomplete") == 'true') {// autocompletion using solr 
    var $input = $("#searchbox input[type=text]"),
        width = $("#searchbox").width()-7,
        scriptUrl = foswiki.getPreference("SCRIPTURL") + '/rest/SolrPlugin/autocomplete',
        now = (new Date).getTime(),
        submitButton = $input.parent().find(".foswikiSubmit");

    if ($input.length) {
      $input.autocomplete({
        source: scriptUrl + '?t='+ now,
        loading: function(event) {
          //console.log("got loading event");
          submitButton.hide();
        },
        unloading: function(event) {
          //console.log("got unloading event");
          submitButton.show();
        }
      }).data("autocomplete")._renderItem = function(ul, item) {
        return $("<li></li>")
          .data("item.autocomplete", item)
          .append("<a><table width='100%'><tr><td>"+item.label+"</td><td align='right'>"+item.frequency+"</td></tr></table></a>")
          .appendTo(ul);
      };
    }
  }

  // raw dialog
if (0) {
  $(".natRawTopicAction").click(function() { 
    var $this = $(this), href = $this.attr("href");
    $.blockUI({
      message:"<h1>Loading wiki text ...</h1>",
      fadeIn: 0,
      fadeOut: 0
    });
    foswiki.openDialog("#natPreviewRaw", {
      persist:false, 
      containerCss: {
        width:800
      },
      onShow: function(dialog) { 
        var web = foswiki.getPreference("WEB"),
            topic = foswiki.getPreference("TOPIC"),
            url = href+"&raw=text&skin=text";
        $.unblockUI();
        dialog.container.find(".topic").text(web.replace(/\//, ".")+"."+topic);
        dialog.container.find(".separate").attr("target", "_blank").click(function() {
          $.modal.close();
        });

        $.ajax({
          url: url,
          async:false,
          dataType:"text",
          success: function(data, status, xhr) {
            var $textarea = dialog.container.find(".foswikiTextarea");
            $textarea.text(data);
            setTimeout(function() { $textarea.focus(); }, 100);
          }
        });
      } 
    }); 
    return false; 
  }); 
}

  // replace hr with a div.hr on ie7
  if ($.browser.msie && $.browser.version == 7.0) {
    $("hr").livequery(function() {
      $(this).replaceWith("<div class='hr' />");
    });
  }

});

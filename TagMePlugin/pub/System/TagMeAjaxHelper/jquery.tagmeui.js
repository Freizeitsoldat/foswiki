'use strict';jQuery(document).ready(function(){(function($){$.fn.tagmeui=function(options){$(this).each(function(){var tagmeui=new TagMeUI($(this),options);tagmeui.initTagField();});return this;};function TagMeUI(caller,options){var that=this;this.caller=caller;this.urlQuery=$.query;this.cloudQuery=this.urlQuery.copy();this.cloudQuery.SET('skin','text');this.cloudQuery.SET('contenttype','text/plain');this.cloudQuery.SET('section','cloud');this.tags=foswiki.TagMePlugin.jquitags.split(',');if(!this.cloudQuery.get('qcallingweb')){this.cloudQuery.SET('qcallingweb',foswiki.web);}
this.settings={cloudSpinner:'#tagmejqtag',cloudContainer:'#tagmejqcloud',cloudWeb:(function(){var web=that.cloudQuery.get('qcallingweb');if(!web){web=foswiki.web;}
if(!that.cloudQuery.get('tpweb')){that.cloudQuery.SET('tpweb',web);}
return web;}()),cloudGetUrl:foswiki.scriptUrlPath+'/view/'+
foswiki.systemWebName+'/TagMeAjaxHelper',cloudUiJustThisWeb:'#tagmeCheckboxJustThisWeb',cloudUiJustMe:'#tagmeCheckboxJustMe',cloudModalOpts:{opacity:7,position:['50px',null],maxWidth:(document.width-50),persist:true,onShow:function(){$('#simplemodal-overlay').click(function(){$.modal.close();});}},taglistSpinner:'#tagmejqtagstatus',taglistContainer:'#tagmejqcontainer',taglistInputField:'#tagmejqinputfield',tagLinkUrl:foswiki.scriptUrlPath+'/view/'+
foswiki.systemWebName+'/TagMeSearch',tagLinkTitle:'Other topics with this tag',tagPostUrl:foswiki.scriptUrlPath+'/viewauth/'+foswiki.web+
'/'+foswiki.topic,autocompleteUrl:foswiki.scriptUrlPath+'/view/'+
foswiki.systemWebName+'/TagMeAjaxHelper',autocompleteOpts:{extraParams:{section:'tagquery',contenttype:'text/plain',skin:'text'},autoFill:true,matchCase:false,multiple:false,max:0,mustMatch:false}};$.extend(this.settings,options);}
TagMeUI.prototype.actOnMissingTag=function(tagName,inList,action,finishHandler){var didModify=false,that=this;if($.inArray(tagName,inList)===-1){$(this.settings.taglistSpinner).addClass('spinning');$.post(this.settings.postUrl,{tpaction:action,tptag:tagName,contenttype:'text/plain',skin:'tagmejquiajax'},function(data){that.linkifyTagText(that.settings.taglistContainer);$(that.settings.taglistSpinner).removeClass('spinning');finishHandler(tagName);});didModify=true;}
return didModify;};TagMeUI.prototype.linkifyTagText=function(selector){var that=this;$(selector+' > form > div.jqTextboxListContainer > span:not(.linkified)').each(function(index,tagSpan){var tagQuery=$.query.copy(),theTag=$(tagSpan).text();function removeTextNodes(element){$(element).contents().filter(function(){if(this.nodeType===Node.TEXT_NODE){this.textContent='';}});return;}
tagQuery.SET('tag',theTag);tagQuery.SET('qcallingweb',foswiki.web);removeTextNodes(tagSpan);$(tagSpan).append('<a href="'+that.settings.tagLinkUrl+
tagQuery.toString()+'" title="'+
that.settings.tagLinkTitle+'">'+theTag+'</a>');$(tagSpan).addClass('linkified');});return;};TagMeUI.prototype.loadCloud=function(){var that=this;function initDialogue(){function setQueryWithCheckbox(qkey,qvalue,checkbox,sense){if($(checkbox).is(':checked')===sense){that.cloudQuery.SET(qkey,qvalue);}else{that.cloudQuery=that.cloudQuery.remove(qkey);}}
if($('#simplemodal-container').width()>$(document).width()-50){$('#simplemodal-container').width($(document).width()-50);}
$(that.settings.cloudUiJustThisWeb).click(function(){setQueryWithCheckbox('tpweb',that.settings.cloudWeb,that.settings.cloudUiJustThisWeb,false);that.loadCloud();});$(that.settings.cloudUiJustMe).click(function(){setQueryWithCheckbox('tpuser','me',that.settings.cloudUiJustMe,true);that.loadCloud();});}
$(this.settings.cloudSpinner).addClass('spinning');$(this.settings.cloudContainer).load(this.settings.cloudGetUrl+
this.cloudQuery.toString(),function(){$(that.settings.cloudSpinner).removeClass('spinning');$(that.settings.cloudContainer).modal(that.settings.cloudModalOpts);initDialogue();});};TagMeUI.prototype.initTagField=function(){var that=this;$(this.settings.taglistInputField).textboxlist({onSelect:function(input){var selectedTags=input.currentValues,didAdd=false;$.each(selectedTags,function(index,tagName){if(that.actOnMissingTag(tagName,that.tags,'add',function(tagName){that.tags.push(tagName);})){didAdd=true;}});if(!didAdd){$.each(that.tags,function(index,tagName){if(!that.actOnMissingTag(tagName,selectedTags,'remove',function(tagName){that.tags.pop(tagName);})){that.linkifyTagText(that.settings.taglistContainer);}});}},autocomplete:this.settings.autocompleteUrl,autocompleteOpts:this.settings.autocompleteOpts});this.linkifyTagText(this.settings.taglistContainer);$(this.settings.cloudSpinner).click(function(){that.loadCloud();});};}(jQuery));$.fn.tagmeui();});;

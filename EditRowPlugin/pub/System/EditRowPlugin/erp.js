var rowDirty=0;Behaviour.register({'.EditRowPluginInput':function(element){element.onchange=function(){rowDirty=1;}}});Behaviour.register({'.EditRowPluginDiscardAction':function(element){element.onclick=function(){if(rowDirty){if(!confirm("This action will discard your changes.")){return false;}}
return true;}}});
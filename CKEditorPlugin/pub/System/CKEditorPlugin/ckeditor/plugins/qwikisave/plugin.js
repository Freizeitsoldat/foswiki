﻿/*
Copyright (c) 2003-2010, CKSource - Frederico Knabben. All rights reserved.
For licensing, see LICENSE.html or http://ckeditor.com/license
*/

/**
 * @fileSave plugin.
 */

(function()
{
	var saveCmd =
	{
		modes : { wysiwyg:1, source:1 },

		exec : function( editor )
		{
			var $form = editor.element.$.form;

			if ( $form )
			{
				try
				{
					$form.save.click();
				}
				catch( e )
				{
					try
					{
						$form.submit();
					}
					catch(e)
					{
						// If there's a button named "submit" then the form.submit
						// function is masked and can't be called in IE/FF, so we
						// call the click() method of that button.
						if ( $form.submit.click )
							$form.submit.click();
					}
				}
			}
		}
	};
	
	var cancelCmd =
	{
		modes : { wysiwyg:1, source:1 },

		exec : function( editor )
		{
			var $form = editor.element.$.form;

			if ( $form )
			{
				try
				{
					$form.cancel.click();
				}
				catch( e )
				{
					
				}
			}
		}
	};

	var pluginName = 'qwikisave';

	// Register a plugin named "save".
	CKEDITOR.plugins.add( pluginName,
	{
		init : function( editor )
		{
			var command = editor.addCommand( pluginName, saveCmd );
			command.modes = { wysiwyg : !!( editor.element.$.form ) };

			editor.ui.addButton( 'Save',
				{
					label : editor.lang.save,
					command : pluginName
				});
			
			//Abbrechen
			editor.addCommand( 'cancel', cancelCmd );
			editor.ui.addButton( 'Cancel',
				{
					label	: editor.lang.common.cancel,
					command : 'cancel',
					icon	: this.path + 'images/icon_close.gif'
				});
		}
	});
})();
::xo::library doc {
    XoWiki - package specific methods

    @creation-date 2006-10-10
    @author Gustaf Neumann
    @cvs-id $Id$
}

namespace eval ::xowiki {

  ::xo::PackageMgr create ::xowiki::Package \
      -superclass ::xo::Package \
      -pretty_name "XoWiki" \
      -package_key xowiki \
      -parameter {
	{folder_id 0}
	{force_refresh_login false}
      }
  # {folder_id "[::xo::cc query_parameter folder_id 0]"}

  Package ad_proc instantiate_page_from_id {
    {-revision_id 0} 
    {-item_id 0}
    {-user_id -1}
    {-parameter ""}
  } {
    Instantiate a page in situations, where the context is not set up
    (e.g. we have no package object). This call is convenient
    when testing e.g. from the developer shell
  } {
    #TODO can most probably further simplified
    set page [::xo::db::CrClass get_instance_from_db -item_id $item_id -revision_id $revision_id]

    #my log "--I get_instance_from_db i=$item_id revision_id=$revision_id page=$page, package_id=[$page set package_id]"

    set folder_id [$page parent_id] 
    if {[apm_version_names_compare [ad_acs_version] 5.2] <= -1} {
      set package_id [db_string [my qn get_pid] \
                          "select package_id from cr_folders where folder_id = $folder_id"]
      $page package_id $package_id
    } else {
      set package_id [$page set package_id]
    }
    ::xowiki::Package initialize \
	-package_id $package_id -user_id $user_id \
	-parameter $parameter -init_url false -actual_query ""
    ::$package_id set_url -url [::$package_id pretty_link [$page name]]
    return $page
  }

  Package ad_proc get_url_from_id {{-item_id 0} {-revision_id 0}} {
    Get the full URL from a page in situations, where the context is not set up.
    @see instantiate_page_from_id
  } {
    set page [::xowiki::Package instantiate_page_from_id \
                  -item_id $item_id -revision_id $revision_id]
    $page volatile
    return [::[$page package_id] url] 
  }

  #
  # URL and naming management
  #
  Package instproc normalize_name {string} {
    set string [string trim $string]
    regsub -all \# $string _ string
    # if subst_blank_in_name is turned on, turn spaces into _
    if {[my get_parameter subst_blank_in_name 1]} {
      regsub -all { +} $string "_" string
    }
    return [ns_urldecode $string]
  }

  Package instproc default_locale {} {
    if {[my get_parameter use_connection_locale 0]} {
      # we return the connection locale (if not connected the system locale)
      set locale [::xo::cc locale]
    } else {
      # return either the package locale or the site-wide locale
      set locale [lang::system::locale -package_id [my id]]
    }
    return $locale
  }
  
  Package instproc default_language {} {
    return [string range [my default_locale] 0 1]
  }

  Package array set www-file {
    admin 1
    diff 1
    doc 1
    edit 1
    error-template 1
    portlet 1     portlet-ajax 1  portlets 1
    prototypes 1 
    ressources 1
    revisions 1 
    view-default 1 view-links 1 view-plain 1 oacs-view 1 oacs-view2 1 oacs-view3 1
    view-book 1 view-book-no-ajax 1 view-oacs-docs 1
    download 1
  }
  
  Package instproc get_lang_and_name {-path -name {-default_lang ""} vlang vlocal_name} {
    my upvar $vlang lang $vlocal_name local_name 
    if {[info exists path]} {
      # 
      # Determine lang and name from a path with slashes
      #
      if {[regexp {^pages/(..)/(.*)$} $path _ lang local_name]} {
      } elseif {[regexp {^(..)/(.*)$} $path _ lang local_name]} {

        # TODO we should be able to get rid of this by using a canonical /folder/ in 
        # case of potential conflicts, like for file....

          # check if we have a LANG - FOLDER "conflict"
          set item_id [::xo::db::CrClass lookup -name $lang -parent_id [my folder_id]]
          if {$item_id} {
            my msg "We have a lang-folder 'conflict' (or a two-char folder) with folder: $lang"
            set local_name $path
            if {$default_lang eq ""} {set default_lang [my default_language]}
            set lang $default_lang
          }

      } elseif {[regexp {^(..):(.*)$} $path _ lang local_name]} {
      } elseif {[regexp {^(file|image|swf|download/file|tag)/(.*)$} $path _ lang local_name]} {
      } else {
        set local_name $path
        if {$default_lang eq ""} {set default_lang [my default_language]}
        set lang $default_lang
      }
    } elseif {[info exists name]} {
      # 
      # Determine lang and name from a names as it stored in the database
      #
      if {![regexp {^(..):(.*)$} $name _ lang local_name]} {
        if {![regexp {^(file|image|swf):(.*)$} $name _ lang local_name]} {
          set local_name $name
          if {$default_lang eq ""} {set default_lang [my default_language]}
          set lang $default_lang
        }
      }
    }
  }
  
  Package instproc get_parent_and_name {-path:required -lang:required -folder_id:required vparent vlocal_name} {
    my upvar $vparent parent $vlocal_name local_name 
    #my log "path=$path folder_id=$folder_id"
    if {[regexp {^([^/]+)/(.+)$} $path _ parent local_name]} {
      # pages are stored with a lang prefix
      set p [::xo::db::CrClass lookup -name ${lang}:$parent -parent_id $folder_id]
      #my log "check '$parent' returned $p"
      if {$p == 0} {
        # folders are stored without a lang prefix
        set p [::xo::db::CrClass lookup -name $parent -parent_id $folder_id]
      }
      if {$p != 0} {
        if {[regexp {^([^/]+)/(.+)$} $local_name _ parent2 local_name2]} {
          set p2 [my get_parent_and_name -path $local_name -lang $lang -folder_id $p parent local_name]
          #my log "recursive call for '$local_name' parent_id=$p returned $p2"
          if {$p2 != 0} {
           set p $p2
          }
        }
      }
      if {$p != 0} {
        return $p 
      }
    }
    set parent ""
    # a trailing slash indicates a directory, remove it from the path
    set local_name [string trimright $path /]
    return $folder_id
  }

  Package instproc get_page_from_name {-name:required} {
    # Check if an instance with this name exists in the current package.
    my get_lang_and_name -name $name lang stripped_name
    set item_id [my lookup -name $lang:$stripped_name]
    if {$item_id != 0} {
      return [::xo::db::CrClass get_instance_from_db -item_id $item_id]
    }
    return ""
  }

  Package instproc folder_path {{-parent_id ""}} {
    #
    # handle different parent_ids
    #
    if {$parent_id ne "" && $parent_id != [my folder_id]} {
      # The item might be in a folder along the folder path.  so it
      # will be found by the object resolver. For the time being, we
      # do nothing more about this.
      
      set path ""
      while {1} {
        # TODO: on the longer range, this should not be required, but we have
        # to solve the folder object problem first...
        if {[::xo::db::sql::content_folder is_folder -item_id $parent_id]} {
          set queryClass ::xo::db::CrFolder
        } else {
          set queryClass ::xo::db::CrClass
        }
        set fo [$queryClass get_instance_from_db -item_id $parent_id]
        set path [$fo name]/$path
        if {[my folder_id] == [$fo parent_id]} break
        if {[$fo parent_id]<0} break
        set parent_id [$fo parent_id]
      }
      return $path
    }

    return ""
  }
    

  Package ad_instproc external_name {
    {-parent_id ""}
    name 
  } {
    Generate a name with a potentially inserted parent name

    @param parent_id parent_id (for now just for download)
    @param name name of the wiki page
  } {
    set folder [my folder_path -parent_id $parent_id]
    if {$folder ne ""} {
      # Return the stripped name for sub-items, the parent has already
      # the language prefix
      my get_lang_and_name -name $name lang stripped_name
      return $folder$stripped_name
    }
    return $name

  }

  Package ad_instproc pretty_link {
    {-anchor ""} 
    {-query ""} 
    {-absolute:boolean false} 
    {-siteurl ""}
    {-lang ""} 
    {-parent_id ""}
    {-download false} 
    name 
  } {
    Generate a (minimal) link to a wiki page with the specified name.
    Pratically all links in the xowiki systems are generated through this
    function. 

    @param anchor anchor to be added to the link
    @param absolute make an absolute link (including protocol and host)
    @param lang use the specified 2 character language code (rather than computing the value)
    @param download create download link (without m=download)
    @param parent_id parent_id (for now just for download)
    @param name name of the wiki page
  } {
    #my msg "input name=$name, lang=$lang"
    set default_lang [my default_language]
    
    my get_lang_and_name -default_lang $lang -name $name lang name

    set host [expr {$absolute ? ($siteurl ne "" ? $siteurl : [ad_url]) : ""}]
    if {$anchor ne ""} {set anchor \#$anchor}
    if {$query ne ""} {set query ?$query}
    #my log "--LINK $lang == $default_lang [expr {$lang ne $default_lang}] $name"
    set package_prefix [my get_parameter package_prefix [my package_url]]
    if {$package_prefix eq "/" && [string length $lang]>2} {
      # don't compact the the path for images etc. to avoid conflicts
      # with e.g. //../image/*
      set package_prefix [my package_url]
    }
    #my msg "lang=$lang, default_lang=$default_lang, name=$name, parent_id=$parent_id, package_prefix=$package_prefix"
    
    if {$parent_id eq -100} {
      return ${host}${package_prefix}$query$anchor
    }
    
    set encoded_name [string map [list %2d - %5f _ %2e .] [ns_urlencode $name]]
    set folder [my folder_path -parent_id $parent_id]
    #my msg "folder_path = $folder"

    if {$folder ne ""} {
      # if folder has a different language than the content, we have to provide a prefix....
      regexp {^(..):} $folder _ default_lang
    }

    #my log "h=${host}, prefix=${package_prefix}, folder=$folder, name=$encoded_name anchor=$anchor download=$download"
    #my msg folder=$folder,lang=$lang,default_lang=$default_lang
    if {$download} {
      #
      # use the special download (file) syntax
      #
      set url ${host}${package_prefix}download/file/$folder$encoded_name$query$anchor
    } elseif {$lang ne $default_lang || [[self class] exists www-file($name)]} {
      #
      # If files are physical files in the www directory, add the
      # language prefix
      #
      set url ${host}${package_prefix}${lang}/$folder$encoded_name$query$anchor
    } else {
      #
      # Use the short notation without language prefix
      #
      set url ${host}${package_prefix}$folder$encoded_name$query$anchor
    }
    #my msg "final url=$url"
    return $url
  }

  Package instproc init {} {
    #my log "--R creating + folder_object"
    next
    my require_folder_object
    my set policy [my get_parameter -check_query_parameter false security_policy ::xowiki::policy1]
    #my proc destroy {} {my log "--P "; next}
  }

  Package ad_instproc get_parameter {{-check_query_parameter true} {-type ""} attribute {default ""}} {
    resolves configurable parameters according to the following precedence:
    (1) values specifically set per page {{set-parameter ...}}
    (2) query parameter
    (3) form fields from the parameter_page FormPage
    (4) standard OpenACS package parameter
  } {
    set value [::xo::cc get_parameter $attribute]
    if {$check_query_parameter && $value eq ""} {set value [string trim [my query_parameter $attribute]]}
    if {$value eq "" && $attribute ne "parameter_page"} {
      #
      # Try to get the parameter from the parameter_page.  We have to
      # be very cautious here to avoid recursive calls (e.g. when
      # resolve_page_name needs as well parameters such as
      # use_connection_locale or subst_blank_in_name, etc.).
      #
      set pp [my get_parameter parameter_page ""]
      if {$pp ne ""} {
        if {![regexp {/?..:} $pp]} {
          my log "Error: Name of parameter page '$pp' of package [my id] must contain a language prefix"
        } else {
          set page [::xo::cc cache [list [self] get_page_from_item_ref $pp]]
          if {$page eq ""} {
            my log "Error: Could not resolve parameter page '$pp' of package [my id]."
          }
          if {$page ne "" && [$page exists instance_attributes]} {
            array set __ia [$page set instance_attributes]
            if {[info exists __ia($attribute)]} {
              set value $__ia($attribute)
              #my log "got value='$value'"
            }
          }
        }
      }
    }
    #if {$value eq ""} {set value [::[my folder_id] get_payload $attribute]}
    if {$value eq ""} {set value [next $attribute $default]}
    if {$type ne ""} {
      # to be extended and generalized
      switch $type {
        word {if {[regexp {\W} $value]} {error "value '$value' contains invalid character"}}
        default {error "requested type unknown: $type"}
      }
    }
    #my log "           $attribute returns '$value'"
    return $value
  }

  Package instproc resolve_package_path {path name_var} {
    #
    # In case, we can resolve the path against an xowiki instance,
    # require the package, set the provided name of the object and
    # return the package_id. If we cannot resolve the name, turn 0.
    #
    my upvar $name_var name
    if {[regexp {^/(/.*)$} $path _ path]} {
      array set "" [site_node::get_from_url -url $path]
      if {$(package_key) eq "acs-subsite"} {
        # the main site
        return 0
      }
      set package_id $(package_id)
      set package_class [::xo::PackageMgr get_package_class_from_package_key $(package_key)]
      if {$package_class ne ""} {
        # we found an xo::Package, but is it an xowiki package?
        set classes [concat $package_class [$package_class info heritage]]
        if {[lsearch $classes ::xowiki::Package] > -1} {
          # yes, it is an xowiki::package, compute the name and return the package_id
          ::xowiki::Package require $package_id
          set name [string range $path [string length $(url)] end]
          return $package_id
        }
      }
    } elseif {!([string match "http*://*" $path] || [string match "ftp://*" $path])} {
      return [my id]
    }

    return 0
  }

  Package instproc get_package_id_from_page_name {{-default_lang ""} page_name} {
    #
    # Return package id + remaining page name
    #
    set package_id [my id]
    if {[regexp {^/(/[^/]+/)(.*)$} $page_name _ url page_name]} {
      set provided_name $page_name
      array set "" [site_node::get_from_url -url $url]
      if {$(package_id) eq ""} {return ""}
      if {$(name) ne ""} {set package_id $(package_id)}
      ::xowiki::Package require $package_id
      my get_lang_and_name -default_lang $default_lang -path $page_name lang stripped_name
      set page_name $lang:$stripped_name
      set url $(url)
      set search 0
    } else {
      set url [my url]/
      set provided_name $page_name
      set search 1
    }
    #my msg [self args]->[list package_id $package_id page_name $page_name url $url provided_name $provided_name search $search]
    return [list package_id $package_id page_name $page_name url $url provided_name $provided_name search $search]
  }

  Package instproc resolve_page_name {{-default_lang ""} page_name} {
    #
    # This is a very simple version for resolving page names in an
    # package instance.  It can be called either with a full page
    # name with a language prefix (as stored in the CR) for the
    # current package, or with a path (starting with a //) pointing to
    # an xowiki instance followed by the page name.
    #
    # Examples
    #    ... resolve_page_name en:index
    #    ... resolve_page_name //xowiki/en:somepage
    #
    # The method returns either the page object or empty ("").
    #
    array set "" [my get_package_id_from_page_name $page_name]
    if {![info exists (package_id)]} {return ""}
    
    #my log "final resolve $(package_id) '$(page_name)'"
    return [$(package_id) resolve_request -default_lang $default_lang -simple true -path $(page_name) method_var]
  }

  Package instproc resolve_page_name_and_init_context {{-lang} page_name} {
    set page ""
    #
    # take a local copy of the package_id, since it is possible
    # that the variable package_id might changed to another instance.
    #
    set package_id [my id]
    array set "" [my get_package_id_from_page_name $page_name]
    if {$(package_id) != $package_id} {
      #
      # Handle cross package resolve requests
      #
      # Note, that package::initialize might change the package id.
      # Preserving the package-url is just necessary, if for some
      # reason the same package is initialized here with a different 
      # url. This could be done probably with a flag to initialize,
      # but we get below the object name from the package_id...
      #
      #my log "cross package request $page_name"
      #
      set last_package_id $package_id
      set last_url [my url]
      #
      # TODO: We assume here that the package is an xowiki package.
      #       The package might be as well a subclass of xowiki...
      #       For now, we fixed the problem to perform reclassing in
      #       ::xo::Package init and calling a per-package instance 
      #       method "initialize"
      #
      ::xowiki::Package initialize -parameter {{-m view}} -url $(url)$(provided_name) \
          -actual_query ""
      #my log "url=$url=>[$package_id serialize]"
      
      if {$package_id != 0} {
        #
        # For the resolver, we create a fresh context to avoid recursive loops, when
        # e.g. revision_id is set through a query parameter...
        #
        set last_context [expr {[$package_id exists context] ? [$package_id context] : "::xo::cc"}]
        $package_id context [::xo::Context new -volatile]
        set object_name [$package_id set object]
        #my log "cross package request got object=$object_name"
        #
        # A user might force the language by preceding the
        # name with a language prefix.
        #
        #my log "check '$object_name' for lang prefix"
        if {![regexp {^..:} $object_name]} {
          if {![info exists lang]} {
            set lang [my default_language]
          }
          set object_name ${lang}:$object_name
        }
        set page [$package_id resolve_page -simple true $object_name __m]
        $package_id context $last_context
      }
      $last_package_id set_url -url $last_url
      
    } else {
      # It is not a cross package request
      set last_context [expr {[$package_id exists context] ? [$package_id context] : "::xo::cc"}]
      $package_id context [::xo::Context new -volatile]
      set page [$package_id resolve_page -use_package_path $(search) $(page_name) __m]
      $package_id context $last_context
    }
    #my log "returning $page"
    return $page
  }


  Package instproc show_page_order {} {
    return [my get_parameter display_page_order 1]
  }

  #
  # conditional links
  #
  Package ad_instproc make_link {{-with_entities 0} -privilege -link object method args} {
    Creates conditionally a link for use in xowiki. When the generated link 
    will be activated, the specified method of the object will be invoked.
    make_link checks in advance, wether the actual user has enough 
    rights to invoke the method. If not, this method returns empty.
       
    @param Object The object to which the link refers to. If it is a package_id it will base \
        to the root_url of the package_id. If it is a page, it will base to the page_url
    @param method Which method to use. This will be appended as "m=method" to the url. 

    Examples for methods:
     <ul>
     <li>view: To view and existing page</li>
     <li>edit: To edit an existing page</li>
     <li>revisions: To view the revisions of an existing page</li>
    </ul>

    @param args List of attributes to be append to the link. Every element 
    can be an attribute name, or a "name value" pair. Behaves like export_vars.

    @return The link or empty
    @see export_vars
  } {
    my instvar id

    set computed_link ""
    #my msg "obj=$object, [$object info class]"
    if {[$object istype ::xowiki::Package]} {
      set base  [my package_url]
      if {[info exists link]} {
        set computed_link [uplevel export_vars -base [list $base$link] [list $args]]
      } else {
        lappend args [list $method 1]
        set computed_link [uplevel export_vars -base [list $base] [list $args]]
        }
    } elseif {[$object istype ::xowiki::Page]} {
      if {[info exists link]} {
        set base $link
      } else {
        set base [my url]
        #my msg "base = '[my url]'"
      }
      lappend args [list m $method]
      set computed_link [uplevel export_vars -base [list $base] [list $args]]
      #my msg "computed_link = '$computed_link'"
    }
    if {$with_entities} {
      regsub -all & $computed_link "&amp;" computed_link
    }

    # provide links based in untrusted_user_id
    set party_id [::xo::cc set untrusted_user_id]
    if {[info exists privilege]} {
      #my log "-- checking priv $privilege for [self args] from id $id"
      set granted [expr {$privilege eq "public" ? 1 :
                         [::xo::cc permission -object_id $id -privilege $privilege -party_id $party_id] }]
    } else {
      # determine privilege from policy
      #my msg "-- check permissions from $id of object $object $method"
      if {[catch {
	set granted [my check_permissions \
			 -user_id $party_id \
			 -package_id $id \
			 -link $computed_link $object $method]
      } errorMsg ]} {
	my log "error in check_permissions: $errorMsg"
	set granted 0
      }
      #my log "--p $id check_permissions $object $method ==> $granted"
    }
    #my log "granted=$granted $computed_link"
    if {$granted} {
      return $computed_link
    }
    return ""
  }

  Package instproc make_form_link {-form -parent_id -name -nls_language -return_url} {
    my instvar id
    # use the same instantiate_forms as everywhere; TODO: will go to a different namespace
    set form_id [lindex [::xowiki::Weblog instantiate_forms -forms $form -package_id $id] 0]
    if {$form_id ne ""} {
      ::xo::db::CrClass get_instance_from_db -item_id $form_id
      set form_link [my pretty_link -parent_id [$form_id parent_id] $form]
      return [my make_link -with_entities 0 -link $form_link $form_id \
                  create-new return_url title parent_id name nls_language]
    }
  }

  #Package instproc make_new_child_link {-form -parent -name -nls_language -return_url} {
  #  my instvar id
  #  if {[info exists form]} {
  #    return [my make_link -with_entities 0 $parent \
  #                create-child form return_url title name nls_language]
  #  }
  #}

  Package instproc create_new_snippet {
    {-object_type ::xowiki::Page}
    provided_name
  } {
    my get_lang_and_name -path $provided_name lang local_name
    set name ${lang}:$local_name
    set new_link [my make_link [my id] edit-new object_type return_url name] 
    if {$new_link ne ""} {
      return "<p>Do you want to create page <a href='$new_link'>$name</a> new?"
    } else {
      return ""
    }
  }

  Package instproc invoke {-method {-error_template error-template} {-batch_mode 0}} {
    set page [my resolve_page [my set object] method]
    #my log "--r resolve_page => $page"
    if {$page ne ""} {
      if {[$page procsearch $method] eq ""} {
	return [my error_msg "Method <b>'$method'</b> is not defined for this object"]
      } else {
        #my log "--invoke [my set object] id=$page method=$method" 
        if {$batch_mode} {[my id] set __batch_mode 1}
	set r [my call $page $method ""]
        if {$batch_mode} {[my id] unset __batch_mode}
        return $r
      }
    } else {
      # the requested page was not found, provide an error message and 
      # an optional link for creating the page
      set path [::xowiki::Includelet html_encode [my set object]]
      set edit_snippet [my create_new_snippet $path]
      return [my error_msg -template_file $error_template \
		  "Page <b>'$path'</b> is not available. $edit_snippet"]
    }
  }

  Package instproc error_msg {{-template_file error-template} error_msg} {
    my instvar id
    if {![regexp {^[./]} $template_file]} {
      set template_file /packages/xowiki/www/$template_file
    }
    set context [list [$id instance_name]]
    set title Error
    set header_stuff [::xo::Page header_stuff]
    set index_link [my make_link -privilege public -link "" $id {} {}]
    set link [my query_parameter "return_url" ""]
    if {$link ne ""} {set back_link $link}
    set top_includelets ""; set content $error_msg
    $id return_page -adp $template_file -variables {
      context title index_link back_link header_stuff error_msg 
      top_includelets content
    }
  }

  Package instproc resolve_page {{-use_package_path true} {-simple false} -lang object method_var} {
    #
    # Try to resolve from object (path) and query parameter the called
    # object (might be a packge or page) and the method to be called
    #
    upvar $method_var method
    my instvar id

    # get the default language if not specified
    if {![info exists lang]} {
      set lang [my default_language]
    }

    #my log "resolve_page '$object', default-lang $lang"
    #
    # First, resolve package level methods, 
    # having the syntax PACKAGE_URL?METHOD&....
    #

    if {$object eq ""} {
      #
      # We allow only to call methods defined by the policy
      #
      set exported [[my set policy] defined_methods Package]
      foreach m $exported {
	#my log "--QP my exists_query_parameter $m = [my exists_query_parameter $m] || [my exists_form_parameter $m]"
        if {[my exists_query_parameter $m] || [my exists_form_parameter $m]} {
          set method $m  ;# determining the method, similar file extensions
          return [self]
        }
      }
    }

    if {[string match "//*" $object]} {
      # we have a reference to another instance, we cant resolve this from this package.
      # Report back not found
      return ""
    }

    #my log "--o object is '$object'"
    if {$object eq ""} {
      # we have no object, but as well no method callable on the package
      set object [$id get_parameter index_page "index"]
      #my log "--o object is now '$object'"
    }
    #
    # second, resolve object level
    #
    set page [my resolve_request -default_lang $lang -simple $simple -path $object method]

    #my log "--o resolving object '$object' -default_lang $lang -simple $simple returns '$page'"
    if {$simple || $page ne ""} {
      return $page
    }

    my get_lang_and_name -default_lang $lang -path $object lang stripped_name

    # stripped object is the object without a language prefix
    set stripped_object $object
    regexp {^..:(.*)$} $object _ stripped_object

    # try standard page
    set standard_page [$id get_parameter ${object}_page]
    if {$standard_page ne ""} {
      set page [my resolve_request -default_lang [::xo::cc lang] -path $standard_page method]
      #my log "--o resolving standard_page '$standard_page' returns $page"
      if {$page ne ""} {
        return $page
      }

      # Maybe we are calling from a different language, but the
      # standard page with en: was already instantiated.
      set standard_page "en:$stripped_object"
      set page [my resolve_request -default_lang en -path $standard_page method]
      #my msg "resolve -default_lang en -path $standard_page returns --> $page"
      if {$page ne ""} {
        return $page
      }
    }

    # Maybe, a prototype page was imported with language en:, but the current language is different
    if {$lang ne "en"} {
      set page [my resolve_request -default_lang en -path $stripped_object method]
      #my msg "resolve -default_lang en -path $stripped_object returns --> $page"
      if {$page ne ""} {
	return $page
      }
    }

    if {$use_package_path} {
      # Check for this page along the package path
      foreach package [my package_path] {
        set page [$package resolve_page -simple $simple -lang $lang $object method]
        if {$page ne ""} {
          #my msg "set_resolve_context inherited -package_id [my id] -parent_id [my folder_id]"
	  $page set_resolve_context -package_id [my id] -parent_id [my folder_id]
	  return $page
        }
      }
    }
    
    set page [::xowiki::Package get_site_wide_page -name en:$stripped_name]
    #my log "get_site_wide_page for en:'$stripped_name' returned $page (stripped name)"
    if {$page ne ""} {
      #my msg "set_resolve_context site-wide -package_id [my id] -parent_id [my folder_id]"
      $page set_resolve_context -package_id [my id] -parent_id [my folder_id]
      return $page
    }

    #my msg "we have to try to import a prototype page for $stripped_object"
    set page [my import-prototype-page $stripped_object]
    if {$page ne ""} {
      return $page
    }
    my log "no prototype for '$object' found"
    return $page
  }

  Package instproc package_path {} {
    # 
    # Compute a list fo package objects which should be used for
    # resolving ("inheriance of objects from other instances").
    #
    set packages [list]
    set package_url [string trimright [my package_url] /]
    set package_path [my get_parameter PackagePath]
    #
    # To avoid recursions, remove the current package from the list of
    # packages if was accidentally included. Get the package objects
    # from the remaining URLs.
    #
    foreach package_instance_url $package_path {
      #my msg "compare $package_instance_url eq $package_url"
      if {$package_instance_url eq $package_url} continue
      lappend packages ::[::xowiki::Package initialize \
                              -url $package_instance_url/[my set object] \
                              -keep_cc true -init_url false]
    }
    # final sanity check, in case package->initialize is broken
    set p [lsearch $packages ::[my id]]
    if {$p > -1} {set packages [lreplace $packages $p $p]}

    #my msg "[my id] packages=$packages, p=$p"
    return $packages
  }

  Package instproc lookup {
    {-use_package_path true} 
    {-default_lang ""} 
    -name:required 
    -parent_id
  } {
    # Lookup of names from a given parent_id or from the list of
    # configured instances (obtained via package_path).
    #
    array set "" [my get_package_id_from_page_name -default_lang $default_lang $name]
    #my msg "result = [array get {}]"
    if {![info exists (package_id)]} {
      return 0
    }
    
    if {![info exists parent_id]} {set parent_id [$(package_id) folder_id]}
    set item_id [::xo::db::CrClass lookup -name $(page_name) -parent_id $parent_id]
    #my msg "lookup $(page_name) $parent_id in package $(package_id) returns $item_id"
    if {$item_id == 0 && $use_package_path} {
      #
      # Is the page inherited along the package path?
      #
      foreach package [my package_path] {
        set item_id [$package lookup -name $name]
        #my msg "lookup from package $package $name returns $item_id"
        if {$item_id != 0} break
      }
    }
    return $item_id
  }



  #
  # Resolving item refs 
  # (symbolic references to content items and content folders)
  #

  Package ad_instproc item_ref {
    {-use_package_path false}
    {-normalize_name true}
    -default_lang:required 
    -parent_id:required 
    link
  } {

    An item_ref refers to an item in the content repository relative
    to some parent_id. The item might be either a folder or some kind
    of "page" (e.g. a file). An item_ref might be complex,
    i.e. consist of a path of simple_item_refs, separated by "/".
    An item_ref stops at the first unknown part in the path and
    returns item_id == 0 and the appropriate parent_id (and name etc.) 
    for insertion.

  } {
    # A trailing slash says that the last element is a folder. We
    # substitute it to allow easy iteration over the slash separated
    # segments.
    if {[string match */ $link]} {
      set llink [string trimright $link /]\0
    } else {
      set llink $link
    }

    set elements [split $llink /]
    # Get start-page, if path is empty
    if {[llength $elements] == 0} {
      set link [my get_parameter index_page "index"]
      set elements [list $link]
    }

    # Iterate until the first unknown element appears in the path
    # (we can handle only one unknown at a time).
    set nr_elements [llength $elements]
    set n 0
    foreach element $elements {
      set (last_parent_id) $parent_id
      array set "" [my simple_item_ref \
                        -normalize_name $normalize_name \
                        -use_package_path $use_package_path \
                        -default_lang $default_lang \
                        -parent_id $parent_id \
                        -assume_folder [expr {[incr n] < $nr_elements}] \
                        $element]
      if {$(item_id) == 0} {
        set parent_id $(parent_id)
        break
      } else {
        set parent_id $(item_id)
      }
    }

    return [list link $link link_type $(link_type) form $(form) \
                prefix $(prefix) stripped_name $(stripped_name) \
                item_id $(item_id) parent_id $(parent_id)]
  }

  Package instproc item_id_ref {
    item_id
  } {
    set name [::xo::db::CrClass get_name -item_id $item_id]
    set type [::xo::db::CrClass get_object_type -item_id $item_id]
    set parent_id [::xo::db::CrClass get_parent_id -item_id $item_id]
    #my log "lookup returned name=$name (type $type, name $name, type $type)"

    if {$type eq "content_folder"} {
      return [list link_type "folder" prefix "" stripped_name $name parent_id $parent_id]
    } else {
      regexp {^(.+):(.+)$} $name _ prefix stripped_name
      return [list link_type "link" prefix $prefix stripped_name $stripped_name parent_id $parent_id]
    }
  }
 
  Package instproc simple_item_ref {
    -default_lang:required 
    -parent_id:required 
    {-use_package_path true}
    {-normalize_name true}
    {-assume_folder:required false}
    element
  } {
    if {$normalize_name} {
      set element [my normalize_name $element]
    }
    #my msg el=[string map [list \0 MARKER] $element]-assume_folder=$assume_folder
    set (form) ""
    set use_default_lang 0

    if {[regexp {^(file|image|js|css|swf):(.+)$} $element _ (link_type) (stripped_name)]} {
      # (typed) file links
      set (prefix) file
      set name file:$(stripped_name)
    } elseif {[regexp {^(..):([^:]{3,}?):(..):(.+)$} $element _ form_lang form (prefix) (stripped_name)]} {
      array set "" [list link_type "link" form "$form_lang:$form.form"]
      set name $(prefix):$(stripped_name)
      #my msg "FIRST case name=$name, form=$form_lang:$form"
    } elseif {[regexp {^(..):([^:]{3,}?):(.+)$} $element _ form_lang form (stripped_name)]} {
      array set "" [list link_type "link" form "$form_lang:$form.form" prefix $default_lang]
      set name $default_lang:$(stripped_name)
      set use_default_lang 1
      #my msg "SECOND case name=$name, form=$form_lang:$form"
    } elseif {[regexp {^([^:]{3,}?):(..):(.+)$} $element _ form (prefix) (stripped_name)]} {
      array set "" [list link_type "link" form "$default_lang:$form.form"]
      set name $(prefix):$(stripped_name)
      #my msg "THIRD case name=$name, form=$default_lang:$form"
    } elseif {[regexp {^([^:]{3,}?):(.+)$} $element _ form (stripped_name)]} {
      array set "" [list link_type "link" form "$default_lang:$form.form" prefix $default_lang]
      set name $default_lang:$(stripped_name)
      set use_default_lang 1
      #my msg "FOURTH case name=$name, form=$default_lang:$form"
    } elseif {[regexp {^(..):(.+)$} $element _ (prefix) (stripped_name)]} {
      array set "" [list link_type "link"]
      set name $(prefix):$(stripped_name)
    } elseif {[regexp {^(.+)\0$} $element _ (stripped_name)]} {
      array set "" [list link_type "link" form "$default_lang:folder.form" prefix $default_lang]
      set name $default_lang:$(stripped_name)
      set use_default_lang 1
    } elseif {$assume_folder} {
      array set "" [list link_type "link" form "$default_lang:folder.form" prefix $default_lang stripped_name $element]
      set name $default_lang:$element
      set use_default_lang 1
    } else {
      array set "" [list link_type "link" prefix $default_lang stripped_name $element]
      set name $default_lang:$element
      set use_default_lang 1
    }
    set name [string trimright $name \0]
    set (stripped_name) [string trimright $(stripped_name) \0]

    if {$element eq "." || $element eq ".\0"} {
      array set "" [my item_id_ref $parent_id]
      set item_id $parent_id
      set parent_id $(parent_id)
    } elseif {$element eq ".." || $element eq "..\0"} {
      set id [::xo::db::CrClass get_parent_id -item_id $parent_id]
      if {$id > 0} {
        # refuse to traverse past root folder
        set parent_id $id
      }
      array set "" [my item_id_ref $parent_id]
      set item_id $parent_id
      set parent_id $(parent_id)
    } else {
      # with the following construct we need in most cases just 1 lookup

      set item_id [my lookup -use_package_path $use_package_path \
                       -name $name -parent_id $parent_id]
      #my msg "[my id] lookup -use_package_path $use_package_path -name $name -parent_id $parent_id => $item_id"

      if {$item_id == 0} {
        #
        # The first lookup was not successful, so we try again. 
        #
        if {$(link_type) eq "link" && $use_default_lang && $(prefix) ne "en"} {
          #
          # If the name was not specified explicitely (we are using
          # $default_lang), try again with language "en" try again,
          # maybe element is folder in a different language
          #
          set item_id [my lookup -use_package_path $use_package_path \
                           -name en:$(stripped_name) -parent_id $parent_id]
          #my msg "try again in en en:$(stripped_name) => $item_id"
          if {$item_id > 0} {array set "" [list link_type "link" prefix en]}
        }

        # If the item is still unknown, try filename-based lookup,
        # when the entry looks like a filename with an extension.
        if {$item_id == 0 && [string match *.* $element] && ![regexp {[.](form|wf)$} $element]} {
          #
          # Get the mime type to distinguish between images, flash
          # files and ordinary files. 
          #
          set mime_type [::xowiki::guesstype $name]
          set (prefix) file
          switch -glob $mime_type {
            "image/*" {
              set name file:$(stripped_name)
              set (link_type) image
            }
	    application/x-shockwave-flash {
              set name file:$(stripped_name)
              set (link_type) swf
	    }
            default {
              set name file:$(stripped_name)
              set (link_type) file
            }
          }
          set item_id [my lookup -use_package_path $use_package_path \
                           -name file:$(stripped_name) -parent_id $parent_id]
        }
      }
    }

    #my msg "return link_type $(link_type) prefix $(prefix) stripped_name $(stripped_name) form $(form) parent_id $parent_id item_id $item_id"
    return [list link_type $(link_type) prefix $(prefix) stripped_name $(stripped_name) \
                form $(form) parent_id $parent_id item_id $item_id ]
  }

  Package instproc get_page_from_item_ref {
    {-allow_cross_package_item_refs true} 
    {-use_package_path false} 
    {-use_site_wide_pages true} 
    {-use_prototype_pages false} 
    {-default_lang ""}
    {-parent_id ""}
    link
  } {
    #
    # Get page from an item ref name (either with language prefix or
    # not).  First it try to resolve the item_ref from the actual
    # package. If not successful, it checks optionally along the
    # package_path and on the side-wide pages.
    #
    # @returns page object or empty ("").
    #
    if {$allow_cross_package_item_refs} {
      set referenced_package_id [my resolve_package_path $link rest_link]
      if {$referenced_package_id != 0 && $referenced_package_id != [my id]} {
        #my log "get_page_from_item_ref recursive $rest_link in $referenced_package_id"
        return [$referenced_package_id get_page_from_item_ref \
                    -allow_cross_package_item_refs false \
                    -use_package_path $use_package_path \
                    -use_site_wide_pages $use_site_wide_pages \
                    -use_prototype_pages $use_prototype_pages \
                    -default_lang $default_lang \
                    -parent_id $parent_id \
                    $rest_link]
      }
    }

    if {$parent_id eq ""} {
      set parent_id [my folder_id]
    }
    array set "" [my item_ref -normalize_name false \
                      -use_package_path $use_package_path \
                      -default_lang $default_lang \
                      -parent_id $parent_id \
                      $link]
    #my msg "item-ref for '$link' returns [array get {}]"
    if {!$(item_id) && $use_site_wide_pages} {
      set page [::xowiki::Package get_site_wide_page -name $(prefix):$(stripped_name)]
      if {$page ne ""} {
        #my msg "set_resolve_context site_wide_pages [my id]"
        $page set_resolve_context -package_id [my id] -parent_id $parent_id
        return $page
      }
    }
    if {!$(item_id) && $use_prototype_pages} {
      array set "" [my item_ref \
                        -normalize_name false \
                        -default_lang $default_lang \
                        -parent_id $parent_id \
                        $link]
      set page [::xowiki::Package import_prototype_page \
                    -package_key [my package_key] \
                    -name $(stripped_name) \
                    -parent_id $(parent_id) \
                    -package_id [my id] ]
      return $page
    }
    
    if {!$(item_id)} {
      return ""
    }
    return [::xo::db::CrClass get_instance_from_db -item_id $(item_id)]
  }

  #
  # import for prototype pages
  # 

  Package instproc import-prototype-page {{prototype_name ""}} {
    set page ""
    if {$prototype_name eq ""} {
      set prototype_name [my query_parameter import-prototype-page ""]
      set via_url 1
    }
    if {$prototype_name eq ""} {
      error "No name for prototype given"
    }

    set page [::xowiki::Package import_prototype_page \
                  -package_key [my package_key] \
                  -name $prototype_name \
                  -parent_id [my folder_id] \
                  -package_id [my id] ]

    if {[info exists via_url] && [my exists_query_parameter "return_url"]} {
      my returnredirect [my query_parameter "return_url" [my package_url]]
    }
    return $page
  }

  Package proc import_prototype_page { 
            -package_key:required 
            -name:required 
            -parent_id:required 
            -package_id:required
          } {
    set page ""
    set fn [get_server_root]/packages/$package_key/www/prototypes/$name.page
    #my log "--W check $fn"
    if {[file readable $fn]} {
      my instvar id
      # We have the file. We try to create an item or revision from 
      # definition in the file system.
      if {[regexp {^(..):(.*)$} $name _ lang local_name]} {
        set fullName $name
      } else {
        set fullName en:$name
      }
      #my log "--sourcing page definition $fn, using name '$fullName'"
      set page [source $fn]
      $page configure -name $fullName \
          -parent_id $parent_id -package_id $package_id 
      if {![$page exists title]} {
        $page set title $object
      }
      $page destroy_on_cleanup
      $page set_content [string trim [$page text] " \n"]
      $page initialize_loaded_object
      set item_id [::xo::db::CrClass lookup -name $fullName -parent_id $parent_id]
      if {$item_id == 0} {
        $page save_new
      } else {
        # get the page from the CR with all variables
        set p [::xo::db::CrClass get_instance_from_db -item_id $item_id]
        # copy all scalar variables from the prototype page 
        # into the instantiated page 
        foreach v [$page info vars] {
          if {[$page array exists $v]} continue ;# don't copy arrays
          $p set $v [$page set $v]
        }
        $p save
        set page $p
      }
    }
    return $page
  }

  Package proc require_site_wide_pages {} {
    set parent_id -100
    set package_id [::xo::cc package_id]
    set package_key "xowiki"

    foreach n {folder.form link.form} {
      set item_id [::xo::db::CrClass lookup -name en:$n -parent_id $parent_id]
      my ds "lookup en:$n => $item_id"
      if {!$item_id} {
        set page [::xowiki::Package import_prototype_page \
                      -name $n \
                      -package_key $package_key \
                      -parent_id $parent_id \
                      -package_id $package_id ]
      }
    }
  }

  Package proc get_site_wide_page {-name:required} {
    set item_id [::xo::db::CrClass lookup -name $name -parent_id -100]
    #my ds "lookup from base objects $name => $item_id"
    if {$item_id} {
      set page [::xo::db::CrClass get_instance_from_db -item_id $item_id]
      ::xo::Package require [$page package_id]
      return $page
    }
    return ""
  }

  Package instproc call {object method options} {
    my instvar policy id
    set allowed [$policy enforce_permissions \
                     -package_id $id -user_id [::xo::cc user_id] \
                     $object $method]
    if {$allowed} {
      #my log "--p calling $object ([$object name] [$object info class]) '$method'"
      eval $object $method $options
    } else {
      my log "not allowed to call $object $method"
    }
  }
  Package instforward check_permissions {%my set policy} %proc

  Package instproc resolve_request {{-default_lang ""} {-simple false} -path method_var} {
    my instvar folder_id
    #my log "--u [self args]"
    set item_id 0
    set parent_id $folder_id

    if {$path ne ""} {
      #
      # Try first a direct lookup of whatever we got
      #
      set item_id [::xo::db::CrClass lookup -name $path -parent_id $parent_id]
      if {$simple} {
        if {$item_id != 0} {
          return [::xo::db::CrClass get_instance_from_db -item_id $item_id]
        }
        return ""
      }

      #my log "--try $path ($folder_id/$parent_id) -> $item_id"
      if {$item_id == 0} {
        set nname [my normalize_name $path]
        
        my get_lang_and_name -default_lang $default_lang -path $nname lang stripped_name
        set name ${lang}:$stripped_name
        #my log "--setting name to '$name', lang=$lang, stripped_name='$stripped_name'"

        if {$lang eq "download/file" || $lang eq "file"} { 
          # handle subitems, currently only for files
          set parent_id [my get_parent_and_name -lang $lang \
                             -path $stripped_name -folder_id $folder_id \
                             parent local_name]
          #my log "get_parent_and_name returned parent_id=$parent_id, name='$local_name'"
	  set item_id [::xo::db::CrClass lookup -name file:$local_name -parent_id $parent_id]
          #my log "item_id for file:$local_name = $item_id"
	  if {$item_id != 0 && $lang eq "download/file"} {
	    upvar $method_var method
	    set method download
	  }
        } elseif {$lang eq "tag"} {
	  set tag $stripped_name
	  set summary [::xo::cc query_parameter summary 0]
	  set popular [::xo::cc query_parameter popular 0]
	  set tag_kind [expr {$popular ? "ptag" :"tag"}]
	  set weblog_page [my get_parameter weblog_page]
	  my get_lang_and_name -default_lang $default_lang -path $weblog_page lang stripped_name
	  set name $lang:$stripped_name
	  my set object $weblog_page
	  ::xo::cc set actual_query $tag_kind=$tag&summary=$summary
          #my msg "weblog-page=$weblog_page, actual query=$tag_kind=$tag&summary=$summary"
	}

        if {$item_id == 0} {
          # in case we have a folder "foldername" and a page "foldername/xxx", the page has
          # higher priority.
          set item_id [::xo::db::CrClass lookup -name ${lang}:$stripped_name -parent_id $parent_id]
          #my log "default_lang=$lang, ${lang}:$stripped_name => $item_id\n"
        }

        if {$item_id == 0} {
          set parent_id [my get_parent_and_name -lang $lang \
                             -path $stripped_name -folder_id $folder_id \
                             parent local_name]
          #my log "get_parent_and_name returned parent=$parent, parent_id=$parent_id, deflang $lang name='$local_name'"
          my get_lang_and_name -default_lang $lang -path $local_name lang stripped_name
          set item_id [::xo::db::CrClass lookup -name ${lang}:$stripped_name -parent_id $parent_id]
          #my log "--try  ${lang}:$stripped_name ($folder_id/$parent_id) -> $item_id"
        }

        if {$item_id == 0} {
          set item_id [::xo::db::CrClass lookup -name $stripped_name -parent_id $parent_id]
          #my log "--try $stripped_name ($folder_id/$parent_id) -> $item_id"
        }
       
      } 
    }

    if {$item_id != 0} {
      set revision_id [my query_parameter revision_id 0]
      set [expr {$revision_id ? "item_id" : "revision_id"}] 0
      #my log "--instantiate item_id $item_id revision_id $revision_id"
      set r [::xo::db::CrClass get_instance_from_db -item_id $item_id -revision_id $revision_id]
      $r set package_id [namespace tail [self]]
      #my log "--instantiate done"
      return $r
    } else {
      return ""
    }
  }

  Package instproc require_folder_object { } {
    my instvar id folder_id
    # TODO: we should make a parameter allowed_page_types (see content_types), 
    # but the package admin should not have necessarily the rights to change it
    set folder_id [my require_root_folder -name "xowiki: $id" \
                       -content_types ::xowiki::Page* ]

    my set folder_id $folder_id
  }


  ###############################################################
  #
  # user callable methods on package level
  #

  Package ad_instproc refresh-login {} {
    Force a refresh of a login and do a redict. Intended for use from ajax.
  } {
    set return_url [my query_parameter return_url]
    if {[::xo::cc user_id] == 0} {
      set url [subsite::get_url]register
      ad_returnredirect [export_vars -base $url return_url]
    } else {
      ad_returnredirect $return_url
    }
  }

  #
  # reindex (for site wide search)
  #

  Package ad_instproc reindex {} {
    reindex all items of this package
  } {
    my instvar folder_id
    set pages [db_list [my qn get_pages] "select page_id from xowiki_page, cr_revisions r, cr_items ci \
      where page_id = r.revision_id and ci.item_id = r.item_id and ci.parent_id = $folder_id \
      and ci.live_revision = page_id"]
    #my log "--reindex returns <$pages>"
    foreach page_id $pages {
      #search::queue -object_id $page_id -event DELETE
      search::queue -object_id $page_id -event INSERT
    }
  }

  #
  # change-page-order (normally called via ajax POSTs)
  #
  Package ad_instproc change-page-order {} {
    Change Page Order for pages by renumbering and filling gaps.
  } {
    my instvar folder_id
    set to    [string trim [my form_parameter to ""]]
    set from  [string trim [my form_parameter from ""]]
    set clean [string trim [my form_parameter clean ""]]  ;# only for inserts

    #set from {1.2 1.3 1.4}; set to {1.3 1.4 1.2}; set clean {...}
    #set from {1.2 1.3 1.4}; set to {1.3 1.4 2.1 1.2}; set clean {2.1}
    #set from {1 2}; set to {1 1.2 2}; set clean {1.2 1.3 1.4}

    if {$from eq "" || $to eq "" || [llength $to]-[llength $from] >1 || [llength $to]-[llength $from]<0} {
      my log "unreasonable request from='$from', to='$to'"
      return
    }
    my log "--cpo from=$from, to=$to, clean=$clean"
    set gap_renames [list]
    #
    # We distinguish two cases:
    # - pure reordering: length(to) == length(from)
    # - insert from another section: length(to) == length(from)+1
    #
    if {[llength $to] == [llength $from]} {
      my log "--cpo reorder"
    } elseif {[llength $clean] > 1} {
      my log "--cpo insert"
      #
      # We have to fill the gap. First, find the newly inserted
      # element in $to.
      #
      foreach e $to {
        if {[lsearch -exact $from $e] == -1} {
          set inserted $e
          break
        }
      }
      if {![info exists inserted]} {error "invalid 'to' list (no inserted element detected)"}
      # 
      # compute the remaining list
      #
      set remaining [list]
      foreach e $clean {if {$e ne $inserted} {lappend remaining $e}}
      #
      # compute rename rename commands for it
      #
      set gap_renames [::xowiki::utility page_order_renames -parent_id $folder_id \
                       -start [lindex $clean 0] -from $remaining -to $remaining]
      foreach {page_id item_id name old_page_order new_page_order} $gap_renames {
        my log "--cpo gap $page_id (name) rename $old_page_order to $new_page_order"
      }
    }
    #
    # Compute the rename commands for the drop target
    #
    set drop_renames [::xowiki::utility page_order_renames -parent_id $folder_id \
                          -start [lindex $from 0] -from $from -to $to]
    #my log "--cpo drops l=[llength $drop_renames]"
    foreach {page_id item_id name old_page_order new_page_order} $drop_renames {
      my log "--cpo drop $page_id ($name) rename $old_page_order to $new_page_order"
    }

    #
    # Perform the actual renames
    #
    set temp_obj [::xowiki::Page new -name dummy -volatile]
    set slot [$temp_obj find_slot page_order]
    db_transaction {
      foreach {page_id item_id name old_page_order new_page_order} [concat $drop_renames $gap_renames] {
        #my log "--cpo UPDATE $page_id new_page_order $new_page_order"
	$temp_obj item_id $item_id
        $temp_obj update_attribute_from_slot -revision_id $page_id $slot $new_page_order
        ::xo::clusterwide ns_cache flush xotcl_object_cache ::$item_id
        ::xo::clusterwide ns_cache flush xotcl_object_cache ::$page_id
      }
    }
    #
    # Flush the page fragement caches (page fragments based on page_order might be sufficient)
    my flush_page_fragment_cache -scope agg
    ns_return 200 text/plain ok
  }



  #
  # RSS 2.0 support
  #
  Package ad_instproc rss {
    -maxentries
    -name_filter
    -entries_of
    -title
    -days 
  } {
    Report content of xowiki folder in rss 2.0 format. The
    reporting order is descending by date. The title of the feed
    is taken from the title, the description
    is taken from the description field of the folder object.
    
    @param maxentries maximum number of entries retrieved
    @param days report entries changed in speficied last days
    
  } {
    set package_id [my id]
    set folder_id [$package_id folder_id]
    if {![info exists name_filter]} {
      set name_filter [my get_parameter -type word name_filter ""]
    }
    if {![info exists entries_of]} {
      set entries_of [my get_parameter entries_of ""]
    }
    if {![info exists title]} {
      set title [my get_parameter PackageTitle [my instance_name]]
    }
    set description [my get_parameter PackageDescription ""]

    if {![info exists days] && 
        [regexp {[^0-9]*([0-9]+)d} [my query_parameter rss] _ days]} {
      # setting the variable days
    } else {
      set days 10
    }
    
    set r [RSS new -destroy_on_cleanup \
	       -package_id [my id] \
	       -name_filter $name_filter \
               -entries_of $entries_of \
	       -title $title \
	       -description $description \
	       -days $days]
    
    #set t text/plain
    set t text/xml
    ns_return 200 $t [$r render]
  }

  #
  # Google sitemap support
  #

  Package ad_instproc google-sitemap {
    {-max_entries ""}
    {-changefreq "daily"}
    {-priority "0.5"}
  } {
    Report content of xowiki folder in google site map format
    https://www.google.com/webmasters/sitemaps/docs/en/protocol.html
    
    @param maxentries maximum number of entries retrieved
    @param package_id to determine the xowiki instance
    @param changefreq changefreq as defined by google
    @param priority priority as defined by google
    
  } {
    set package_id [my id]
    set folder_id [::$package_id folder_id]
   
    set timerange_clause ""
    
    set content {<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.google.com/schemas/sitemap/0.84"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xsi:schemaLocation="http://www.google.com/schemas/sitemap/0.84
	http://www.google.com/schemas/sitemap/0.84/sitemap.xsd">
}

    set sql [::xo::db::sql select \
                 -vars "s.body, p.name, p.creator, p.title, p.page_id,\
                p.object_type as content_type, p.last_modified, p.description" \
                 -from "xowiki_pagex p, syndication s, cr_items ci" \
                 -where "ci.parent_id = $folder_id and ci.live_revision = s.object_id \
              and s.object_id = p.page_id $timerange_clause" \
                 -orderby "p.last_modified desc" \
                 -limit $max_entries]
    #my log $sql
    db_foreach [my qn get_pages] $sql {
      #my log "--found $name"
      if {[string match "::*" $name]} continue
      if {$content_type eq "::xowiki::PageTemplate::"} continue
      
      set time [::xo::db::tcl_date $last_modified tz]
      set time "[clock format [clock scan $time] -format {%Y-%m-%dT%T}]${tz}:00"

      append content <url> \n\
          <loc>[::$package_id pretty_link -absolute true $name]</loc> \n\
          <lastmod>$time</lastmod> \n\
          <changefreq>$changefreq</changefreq> \n\
          <priority>$priority</priority> \n\
          </url> \n
    }
    
    append content </urlset> \n

    #set t text/plain
    set t text/xml
    ns_return 200 $t $content
  }

  Package ad_proc google-sitemapindex {
    {-changefreq "daily"}
    {-priority "priority"}
  } {
    Provide a sitemap index of all xowiki instances in google site map format
    https://www.google.com/webmasters/sitemaps/docs/en/protocol.html
    
    @param maxentries maximum number of entries retrieved
    @param package_id to determine the xowiki instance
    @param changefreq changefreq as defined by google
    @param priority priority as defined by google
    
  } {
  
    set content {<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.google.com/schemas/sitemap/0.84">
}
    foreach package_id  [::xowiki::Package instances] {
      if {![::xo::parameter get -package_id $package_id \
	       -parameter include_in_google_sitemap_index -default 1]} {
	continue
      } 
      set last_modified [db_string [my qn get_newest_modification_date] \
                             "select last_modified from acs_objects where package_id = $package_id \
		order by last_modified desc limit 1"]

      set time [::xo::db::tcl_date $last_modified tz]
      set time "[clock format [clock scan $time] -format {%Y-%m-%dT%T}]${tz}:00"

      #my log "--site_node::get_from_object_id -object_id $package_id"
      array set info [site_node::get_from_object_id -object_id $package_id]

      append content <sitemap> \n\
          <loc>[ad_url]$info(url)sitemap.xml</loc> \n\
          <lastmod>$time</lastmod> \n\
          </sitemap> 
    }
    append content </sitemapindex> \n
    #set t text/plain
    set t text/xml
    ns_return 200 $t $content
  }

  Package instproc google-sitemapindex {} {
    [self class] [self proc]
  }

  #
  # Create new pages
  #

  Package instproc edit-new {} {
    my instvar folder_id id
    set object_type [my query_parameter object_type "::xowiki::Page"]
    set autoname [my get_parameter autoname 0]
    set parent_id [$id query_parameter parent_id ""]
    if {$parent_id eq ""} {set parent_id [$id form_parameter folder_id $folder_id]}
    set page [$object_type new -volatile -parent_id $parent_id -package_id $id]
    #my ds "parent_id of $page = [$page parent_id], cl=[$page info class] parent_id=$parent_id\n[$page serialize]"
    if {$object_type eq "::xowiki::PageInstance"} {
      #
      # If we create a PageInstance via the ad_form based
      # PageInstanceForm, we have to provide the page_template here to
      # be able to validate the name, where "build_name" needs
      # access to the ::xowiki::PageTemplate of the
      # ::xowiki::PageInstance.
      #
      $page set page_template [my form_parameter page_template]
    }

    set source_item_id [$id query_parameter source_item_id ""]
    if {$source_item_id ne ""} {
      set source [$object_type get_instance_from_db -item_id $source_item_id]
      $page copy_content_vars -from_object $source
      set name "[::xowiki::autoname new -parent_id $source_item_id -name [$source name]]"
      #my get_lang_and_name -name $name lang name
      $page set name $name
      #my msg nls=[$page nls_language],source-nls=[$source nls_language],page=$page,name=$name
    } else {
      $page set name ""
    }

    return [$page edit -new true -autoname $autoname]
  }

  #
  # manage categories
  #

  Package instproc manage-categories {} {
    set object_id [my query_parameter object_id]
    if {![string is integer -strict $object_id]} { return [my error_msg "No valid object_id provided!"] }

    # flush could be made more precise in the future
    my flush_page_fragment_cache -scope agg

    my returnredirect [site_node::get_package_url -package_key categories]cadmin/object-map?ctx_id=$object_id&object_id=$object_id
  }

  #
  # edit a single category tree
  #

  Package instproc edit-category-tree {} {
    set object_id [my query_parameter object_id]
    if {![string is integer -strict $object_id]} { return [my error_msg "No valid object_id provided!"] }
    set tree_id   [my query_parameter tree_id]
    if {![string is integer -strict $tree_id]}   { return [my error_msg "No valid tree_id provided!"] }

    # flush could be made more precise in the future
    my flush_page_fragment_cache -scope agg
    my returnredirect [site_node::get_package_url -package_key categories]cadmin/tree-view?tree_id=$tree_id&ctx_id=$object_id&object_id=$object_id
  }


  #
  # Package import
  #

  Package ad_instproc import {-user_id -folder_id {-replace 0} -objects {-create_user_ids 0}} {
    import the specified pages into the xowiki instance
  } {
    if {![info exists folder_id]}  {set folder_id  [my folder_id]}
    if {![info exists user_id]}    {set user_id    [::xo::cc user_id]}
    if {![info exists objects]}    {set objects    [::xowiki::Page allinstances]}

    set msg "processing objects: $objects<p>"
    set importer [Importer new -package_id [my id] -folder_id $folder_id -user_id $user_id]
    $importer import_all -replace $replace -objects $objects -create_user_ids $create_user_ids
    append msg [$importer report]
  }

  Package instproc flush_references {-item_id:integer,required -name -parent_id} {
    my instvar id folder_id
    if {![info exists parent_id]} {
      set parent_id [::xo::db::CrClass get_parent_id -item_id $item_id]
    }
    if {![info exists name]} {
      set name [::xo::db::CrClass get_name -item_id $item_id]
    }
    my flush_name_cache -name $name -parent_id $parent_id
  }

  Package instproc flush_name_cache {-name:required -parent_id:required} {
    # Different machines in the cluster might have different entries in their caches.
    # Since we use wild-cards to find these, it has to be done on every machine
    ::xo::clusterwide xo::cache_flush_all xowiki_cache link-*-$name-$parent_id
    ::xo::clusterwide ns_cache flush xotcl_object_type_cache $parent_id-$name
  }

  Package instproc delete_revision {-revision_id:required -item_id:required} {
    ::xo::clusterwide ns_cache flush xotcl_object_cache ::$item_id
    ::xo::clusterwide ns_cache flush xotcl_object_cache ::$revision_id
    ::xo::db::sql::content_revision del -revision_id $revision_id
  }

  Package instproc delete {-item_id -name -parent_id} {
    #
    # This delete method does not require an instanantiated object,
    # while the class-specific delete methods in xowiki-procs need these.
    # If a (broken) object can't be instantiated, it cannot be deleted.
    # Therefore we need this package level delete method. 
    # While the class specific methods are used from the
    # application pages, the package_level method is used from the admin pages.
    #
    my instvar id
    #
    # if no item_id given, take it from the query parameter
    #
    if {![info exists item_id]} {
      set item_id [my query_parameter item_id]
      #my log "--D item_id from query parameter $item_id"
    }
    #
    # if name given, take it from the query parameter
    #
    if {![info exists name]} {
      set name [my query_parameter name]
    }

    if {$item_id eq "" && $name ne ""} {
      if {![info exists parent_id]} {set parent_id [my folder_id]}
      if {[set item_id [::xo::db::CrClass lookup -name $name -parent_id $parent_id]] == 0} {
        ns_log notice "lookup of '$name' failed"
        set item_id ""
      }
    } elseif {$item_id ne ""} {
      if {![info exists parent_id]} {
        set parent_id [::xo::db::CrClass get_parent_id -item_id $item_id]
      }
    }

    if {$item_id ne ""} {
      #my log "--D trying to delete $item_id $name"
      set object_type [::xo::db::CrClass get_object_type -item_id $item_id]
      # In case of PageTemplate and subtypes, we need to check
      # for pages using this template
      set classes [concat $object_type [$object_type info heritage]]
      if {[lsearch $classes "::xowiki::PageTemplate"] > -1} {
	set count [::xowiki::PageTemplate count_usages -item_id $item_id]
	if {$count > 0} {
	  return [$id error_msg \
		      [_ xowiki.error-delete_entries_first [list count $count]]]
	}
      }
      if {[my get_parameter "with_general_comments" 0]} {
        #
        # We have general comments. In a first step, we have to delete
        # these, before we are able to delete the item.
        #
        set comment_ids [db_list [my qn get_comments] \
                   "select comment_id from general_comments where object_id = $item_id"]
        foreach comment_id $comment_ids { 
          my log "-- deleting comment $comment_id"
          ::xo::db::sql::content_item del -item_id $comment_id 
        }
      }
      foreach child_item_id [::xo::db::CrClass get_child_item_ids -item_id $item_id] {
        my flush_references -item_id $child_item_id
      }
      $object_type delete -item_id $item_id
      my flush_references -item_id $item_id -name $name -parent_id $parent_id
      my flush_page_fragment_cache -scope agg
    } else {
      my log "--D nothing to delete!"
    }
    my returnredirect [my query_parameter "return_url" [$id package_url]]
  }

  Package instproc flush_page_fragment_cache {{-scope agg}} {
    switch -- $scope {
      agg {set key PF-[my id]-agg-*}
      all {set key PF-[my id]-*}
      default {error "unknown scope for flushing page fragment cache"}
    }
    foreach entry [ns_cache names xowiki_cache $key] {
      ns_log notice "::xo::clusterwide ns_cache flush xowiki_cache $entry"
      ::xo::clusterwide ns_cache flush xowiki_cache $entry
    }
  }

  #
  # Perform per connection parameter caching.  Using the
  # per-connection cache speeds later lookups up by a factor of 15.
  # Repeated parameter lookups are quite likely
  #

  Class ParameterCache
  ParameterCache instproc get_parameter {{-check_query_parameter true}  {-type ""} attribute {default ""}} {
    set key [list [my id] [self proc] $attribute]
    if {[info command "::xo::cc"] ne ""} {
      if {[::xo::cc cache_exists $key]} {
        return [::xo::cc cache_get $key]
      }
      return [::xo::cc cache_set $key [next]]
    } else {
      # in case, we have no ::xo::cc (e.g. during bootstrap).
      ns_log notice "warning: no ::xo::cc available, returning default for parameter $attribute"
      return $default
    }
  }
  Package instmixin add ParameterCache


  #
  # policy management
  #

  Package instproc condition=has_class {query_context value} {
    return [expr {[$query_context query_parameter object_type ""] eq $value}]
  }
  Package instproc condition=has_name {query_context value} {
    return [regexp $value [$query_context query_parameter name ""]]
  }

  Class create Policy -superclass ::xo::Policy

  Policy policy1 -contains {
  
    Class Package -array set require_permission {
      reindex             swa
      change-page-order   {{id admin}}
      import-prototype-page swa
      refresh-login       none
      rss                 none
      google-sitemap      none
      google-sitemapindex none
      manage-categories   {{id admin}}
      edit-category-tree  {{id admin}}
      delete              {{id admin}}
      edit-new            {
	{{has_class ::xowiki::Object} swa} 
	{{has_class ::xowiki::FormPage} nobody} 
	{{has_name {[.](js|css)$}} id admin}
	{id create}
      }
    }

    Class Page -array set require_permission {
      view               none
      revisions          {{package_id write}}
      diff               {{package_id write}}
      edit               {
        {{regexp {name {(weblog|index)$}}} package_id admin} 
        {package_id write}
      }
      save-form-data     {{package_id write}}
      save-attributes    {{package_id write}}
      make-live-revision {{package_id write}}
      delete-revision    {{package_id admin}}
      delete             {{package_id admin}}
      save-tags          login
      popular-tags       login
      create-new         {{parent_id create}}
      create-or-use      {{parent_id create}}
    } -set default_permission {{package_id write}}

    Class Object -array set require_permission {
      edit               swa
    }
    Class File -array set require_permission {
      download           none
    }
    Class Form -array set require_permission {
      list              {{package_id read}}
    }
    Class CrFolder -array set require_permission {
      view           none
      delete         {{package_id admin}}
      edit-new       {{item_id write}}
    }
  }

  Policy policy2 -contains {
    #
    # we require side wide admin rights for deletions and code
    #

    Class Package -array set require_permission {
      reindex             {{id admin}}
      rss                 none
      refresh-login       none
      google-sitemap      none
      google-sitemapindex none
      change-page-order   {{id admin}}
      manage-categories   {{id admin}}
      edit-category-tree  {{id admin}}
      delete              swa
      edit-new            {
	{{has_class ::xowiki::Object} swa} 
	{{has_class ::xowiki::FormPage} nobody} 
	{{has_name {[.](js|css)$}} swa}
	{id create}
      }
    }
    
    Class Page -array set require_permission {
      view               {{package_id read}}
      revisions          {{package_id write}}
      diff               {{package_id write}}
      edit               {
        {{regexp {name {(weblog|index)$}}} package_id admin} 
        {package_id write}
      }
      save-attributes    {{package_id write}}
      make-live-revision {{package_id write}}
      delete-revision    swa
      delete             swa
      save-tags          login
      popular-tags       login
      create-new         {{parent_id create}}
      create-or-use      {{parent_id create}}
    }

    Class Object -array set require_permission {
      edit               swa
    }
    Class File -array set require_permission {
      download           {{package_id read}}
    }
    Class Form -array set require_permission {
      view              {{package_id read}}
      list              {{package_id read}}
    }
  }

  Policy policy3 -contains {
    #
    # we require side wide admin rights for deletions
    # we perform checking on item_ids for pages. 
    #

    Class Package -array set require_permission {
      reindex             {{id admin}}
      rss                 none
      refresh-login       none
      google-sitemap      none
      google-sitemapindex none
      change-page-order   {{id admin}}
      manage-categories   {{id admin}}
      edit-category-tree  {{id admin}}
      delete              swa
      edit-new            {
	{{has_class ::xowiki::Object} swa} 
	{{has_class ::xowiki::FormPage} nobody} 
	{{has_name {[.](js|css)$}} swa}
	{id create}
      }
    }
    
    Class Page -array set require_permission {
      view               {{item_id read}}
      revisions          {{item_id write}}
      diff               {{item_id write}}
      edit               {{item_id write}}
      make-live-revision {{item_id write}}
      save-attributes    {{package_id write}}
      delete-revision    swa
      delete             swa
      save-tags          login
      popular-tags       login
      create-new         {{parent_id create}}
      create-or-use      {{parent_id create}}
    }

    Class Object -array set require_permission {
      edit               swa
    }
    Class File -array set require_permission {
      download           {{package_id read}}
    }
    Class Form -array set require_permission {
      list              {{item_id read}}
    }
#     Class FormPage -array set require_permission {
#       view              {
#         {{is_true {_creation_user = @current_user@}} item_id read}
#         swa
#       }
#     }
  }

  #Policy policy4 -contains {
  #  ::xotcl::Object function -array set require_permission {
  #    f none
  #  } -set default_permission login
  #}
  
  #my log "--set granted [policy4 check_permissions -user_id 0 -package_id 0 function f]"

  #
  # an example with in_state condition...
  #
  Policy policy5 -contains {

    Class Package -array set require_permission {
      reindex             {{id admin}}
      rss                 none
      refresh-login       none
      google-sitemap      none
      google-sitemapindex none
      change-page-order   {{id admin}}
      manage-categories   {{id admin}}
      edit-category-tree  {{id admin}}
      delete              swa
      edit-new            {
        {{has_class ::xowiki::Object} swa}
        {{has_class ::xowiki::FormPage} nobody}
        {{has_name {[.](js|css)$}} swa}
        {id create}
      }
    }
    
    Class Page -array set require_permission {
      view               {{item_id read}}
      revisions          {{item_id write}}
      diff               {{item_id write}}
      edit               {{item_id write}}
      save-attributes    {{item_id write}}
      make-live-revision {{item_id write}}
      delete-revision    swa
      delete             swa
      save-tags          login
      popular-tags       login
      create-new         {{parent_id create}}
      create-or-use      {{parent_id create}}
    }
    
    Class Object -array set require_permission {
      edit               swa
    }
    Class File -array set require_permission {
      download           {{package_id read}}
    }
    Class FormPage -array set require_permission {
      view               creator 
      edit               {
        {{in_state initial|suspended|working} creator} admin
      }
    }
    Class Form -array set require_permission {
      view              admin
      edit              admin
      list              admin
    }
  }

}

::xo::library source_dependent 




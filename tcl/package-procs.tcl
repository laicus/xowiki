namespace eval ::xowiki {

  ::xo::PackageMgr create Package \
      -superclass ::xo::Package \
      -parameter {{folder_id "[::xo::cc query_parameter folder_id 0]"}}

  Package ad_proc instantiate_page_from_id {
    {-revision_id 0} 
    {-item_id 0}
    {-user_id -1}
    {-parameter ""}
  } {
    Instantiate a page in situations, where the context is not set up
    (e.g. we have no package object or folder obect). This call is convenient
    when testing e.g. from the developer shell
  } {
    #TODO can most probably further simplified
    set page [::Generic::CrItem instantiate -item_id $item_id -revision_id $revision_id]
    my log "--I instantiate i=$item_id revision_id=$revision_id page=$page"
    $page folder_id [$page set parent_id] 
    set package_id [$page set package_id]
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
    # if subst_blank_in_name is turned on, turn spaces into _
    if {[my get_parameter subst_blank_in_name 1] != 0} {
      regsub -all { +} $string "_" string
    }
    return $string
  }
  
  Package instproc pretty_link {
    {-absolute:boolean false} {-lang ""} name
  } {
    #my log "--u name=<$name>"
    if {$lang eq ""} {
      if {![regexp {^(..):(.*)$} $name _ lang name]} {
        regexp {^(file|image):(.*)$} $name _ lang name
      }
    }
    if {$lang eq "" && ![regexp {^(:|(file|image))} $name]} {
      #my log "--u name=<$name> need lang"
      set lang [string range [lang::conn::locale -package_id [my id]] 0 1]
    }

    set host [expr {$absolute ? [ad_url] : ""}]
    if {$lang ne ""} {
      return $host[my package_url]$lang/[ad_urlencode $name]
    } else {
      return $host[my package_url][ad_urlencode $name]
    }
  }

  Package instproc init {} {
    next
    my require_folder_object
    my set policy [my get_parameter security_policy ::xowiki::policy1]
  }

  Package instproc get_parameter {attribute {default ""}} {
    set value [::[my folder_id] get_payload $attribute]
    if {$value eq ""} {set value [next]}
    return $value
  }

  Package instproc invoke {-method} {
    my set mime_type text/html
    my set delivery ns_return
    set page [my resolve_page [my set object] method]
    if {$page ne ""} {
      return [my call $page $method]
    } else {
      return [my error_msg "No page <b>'[my set object]'</b> available."]
      #ad_returnredirect "[my package_url]admin/list"
    }
  }

  Package instproc error_msg {error_msg} {
    my instvar id
    set template_file error-template
    if {![regexp {^[./]} $template_file]} {
      set template_file /packages/xowiki/www/$template_file
    }
    set context [list [$id instance_name]]
    set title Error
    $id return_page -adp $template_file -variables {
      context title error_msg
    }
  }

  Package instproc resolve_page {object method_var} {
    upvar $method_var method
    my instvar folder_id id policy
    if {$object eq ""} {
      set exported [$policy defined_methods Package]
      foreach m $exported {
	#my log "--QP my exists_query_parameter $m = [my exists_query_parameter $m]"
        if {[::xo::cc exists_query_parameter $m]} {
          set method $m  ;# the only reason for the upvar
          return [self]
        }
      }
    }
    if {$object eq ""} {
      # we have no object, but as well no method callable on the package
      set object index
    }
    set page [my resolve_request -path $object]
    if {$page ne ""} {
      return $page
    }

    # try standard page
    set standard_page [$id get_parameter ${object}_page]
    if {$standard_page ne ""} {
      set page [my resolve_request -path $standard_page]
      if {$page ne ""} {
        return $page
      }
    } else {
      regexp {../([^/]+)$} $object _ object
      set standard_page "en:$object"
      # maybe we are calling from a different language, but the
      # standard page with en: was already instantiated
      set page [my resolve_request -path $standard_page]
      if {$page ne ""} {
        return $page
      }
    }

    my log "--W object='$object'"
    set fn [get_server_root]/packages/xowiki/www/prototypes/$object.page
    if {[file readable $fn]} {
      # create from default page
      my log "--sourcing page definition $fn"
      set page [source $fn]
      $page configure -name $standard_page \
          -parent_id $folder_id -package_id $id 
      if {![$page exists title]} {
        $page set title $object
      }
      $page destroy_on_cleanup
      $page set_content [string trim [$page text] " \n"]
      $page initialize_loaded_object
      $page save_new
      return $page
    } else {
      my log "no prototype for '$object' found"
      return ""
    }
  }

  Package instproc call {object method} {
    my instvar policy
    if {[$policy check_permissions $object $method]} {
      my log "--p calling $object ([$object info class]) '$method'"
      $object $method
    } else {
      my log "not allowed to call $object $method"
    }
  }
  Package instforward permission_p {%my set policy} %proc

  Package instproc resolve_request {-path} {
    my instvar folder_id
    #my log "--u [self args]"
    [self class] instvar queryparm
    set item_id 0

    if {$path ne ""} {
      set item_id [::Generic::CrItem lookup -name $path -parent_id $folder_id]
      my log "--try $path -> $item_id"
      
      if {$item_id == 0} {
        if {[regexp {^pages/(..)/(.*)$} $path _ lang local_name]} {
        } elseif {[regexp {^(..)/(.*)$} $path _ lang local_name]} {
        } elseif {[regexp {^(..):(.*)$} $path _ lang local_name]} {
        } elseif {[regexp {^(file|image)/(.*)$} $path _ lang local_name]} {
        } else {
          set key queryparm(lang)
          set lang [expr {[info exists $key] ? [set $key] : \
                              [string range [lang::conn::locale] 0 1]}]
          set local_name $path
        }
        set name ${lang}:$local_name
        if {[info exists name]} {
          set item_id [::Generic::CrItem lookup -name $name -parent_id $folder_id]
          my log "--try $name -> $item_id"
        }
        if {$item_id == 0} {
          set nname   [my normalize_name $name]
          set item_id [::Generic::CrItem lookup -name $nname -parent_id $folder_id]
          my log "--try $nname -> $item_id"
        }
      } 
    }
    if {$item_id != 0} {
      set revision_id [my query_parameter revision_id 0]
      set [expr {$revision_id ? "item_id" : "revision_id"}] 0
      #my log "--instantiate item_id $item_id revision_id $revision_id"
      set r [::Generic::CrItem instantiate -item_id $item_id -revision_id $revision_id]
      #my log "--instantiate done  CONTENT\n[$r serialize]"
      $r set package_id [namespace tail [self]]
      return $r
    } else {
      return ""
    }
  }

  Package instproc require_folder_object { } {
    my instvar id folder_id
    my log "--f [::xotcl::Object isobject ::$folder_id] folder_id=$folder_id"

    if {$folder_id == 0} {
      set folder_id [::xowiki::Page require_folder -name xowiki -package_id $id]
    }

    if {![::xotcl::Object isobject ::$folder_id]} {
      # if we can't get the folder from the cache, create it
      if {[catch {eval [nsv_get xotcl_object_cache ::$folder_id]}]} {
        while {1} {
          set item_id [ns_cache eval xotcl_object_type_cache item_id-of-$folder_id {
            set myid [CrItem lookup -name ::$folder_id -parent_id $folder_id]
            if {$myid == 0} break; # don't cache ID if invalid
            return $myid
          }]
          break
        }
        if {[info exists item_id]} {
          # we have a valid item_id and get the folder object
          #my log "--f fetch folder object -object ::$folder_id -item_id $item_id"
          ::xowiki::Object fetch_object -object ::$folder_id -item_id $item_id
        } else {
          # we have no folder object yet. so we create one...
          ::xowiki::Object create ::$folder_id
          ::$folder_id set text "# this is the payload of the folder object\n\n\
                set index_page \"en:index\"\n"
          ::$folder_id set parent_id $folder_id
          ::$folder_id set name ::$folder_id
          ::$folder_id set title ::$folder_id
          ::$folder_id set package_id $id
          ::$folder_id save_new
          ::$folder_id initialize_loaded_object
        }
      }
      
      #::$folder_id proc destroy {} {my log "--f "; next}
      ::$folder_id set package_id $id
      ::$folder_id destroy_on_cleanup
    } else {
      #my log "--f reuse folder object $folder_id [::Serializer deepSerialize ::$folder_id]"
    }
    
    my set folder_id $folder_id
  }

  Package instproc return_page {-adp -variables -form} {
    #my log "--vars=[self args]"
    set __vars [list]
    foreach _var $variables {
      if {[llength $_var] == 2} {
        lappend __vars [lindex $_var 0] [uplevel subst [lindex $_var 1]]
      } else {
        set localvar local.$_var
        upvar $_var $localvar
        if {[info exists $localvar]} {
          # ignore undefined variables
          lappend __vars $_var [set $localvar]
        }
      }
    }

    if {[info exists form]} {
      set level [template::adp_level]
      foreach f [uplevel #$level info vars ${form}:*] {
        lappend __vars &$f $f
        upvar #$level $f $f
      }
    }
    my log "--before adp"  ;#$__vars
    set text [template::adp_include $adp $__vars]
    my log "--after adp"
    return $text
  }


  Package ad_instproc reindex {} {
    reindex all items of this package
  } {
    my instvar folder_id
    set pages [db_list get_pages "select page_id from xowiki_page, cr_revisions r, cr_items i \
      where page_id = r.revision_id and i.item_id = r.item_id and i.parent_id = $folder_id \
      and i.live_revision = page_id"]
    foreach page_id $pages {
      #search::queue -object_id $page_id -event DELETE
      search::queue -object_id $page_id -event INSERT
    }
  }

  Package instproc rss {} {
    my instvar id
    set cmd [list ::xowiki::Page rss -package_id $id]
    if {[regexp {[^0-9]*([0-9]+)d} [my query_parameter rss] _ days]} {
      lappend cmd -days $days
    }
    eval $cmd
  }

  Package instproc edit-new {} {
    my instvar folder_id id
    set object_type [my query_parameter object_type "::xowiki::Page"]
    set page [$object_type new -volatile -parent_id $folder_id -package_id $id]
    return [$page edit -new true]
  }

  Package instproc delete {-item_id -name} {
    my instvar folder_id id
    if {![info exists item_id]} {
      set item_id [my query_parameter item_id]
      my log "--D item_id from query parameter $item_id"
      set name    [my query_parameter name]
    }
    if {$item_id ne ""} {
      my log "--D trying to delete $item_id $name"
      ::Generic::CrItem delete -item_id $item_id
      ns_cache flush xotcl_object_cache ::$item_id
      # we should probably flush as well cached revisions
      if {$name eq "::$folder_id"} {
        my log "--D deleting folder object ::$folder_id"
        ns_cache flush xotcl_object_cache ::$folder_id
        ns_cache flush xotcl_object_type_cache item_id-of-$folder_id
        ::$folder_id destroy
      }
      set key link-*-$name-$folder_id
      foreach n [ns_cache names xowiki_cache $key] {ns_cache flush xowiki_cache $n}
    } else {
      my log "--D nothing to delete!"
    }
    ad_returnredirect [my query_parameter "return_url" [$id package_url]]
  }

  Package instproc condition {method attr value} {
    switch $attr {
      has_class {set result [expr {[my query_parameter object_type ""] eq $value}]}
      default {set result 0}
    }
    #my log "--c [self args] returns $result"
    return $result
  }
 

  Class Policy
  Policy instproc defined_methods {class} {
    set c [self]::$class
    expr {[my isclass $c] ? [$c array names require_permission] : [list]}
  }
  Policy instproc permission_p {object method} {
    foreach class [concat [$object info class] [[$object info class] info heritage]] {
      set c [self]::[namespace tail $class]
      if {![my isclass $c]} continue
      set key require_permission($method)
      if {[$c exists $key]} {
        set permission  [$c set $key]
        if {$permission eq "login" || $permission eq "none"} {
          return 1
        }
        if {$permission eq "swa"} {
          return [acs_user::site_wide_admin_p]
        }
        foreach cond_permission $permission {
          #my log "--cond_permission = $cond_permission"
          switch [llength $cond_permission] {
            3 {foreach {condition attribute privilege} $cond_permission break
              if {[eval $object condition $method $condition]} break
            }
            2 {foreach {attribute privilege} $cond_permission break
              break
            }
          }
        }
        set id [$object set $attribute]
        #my log "--p checking permission::permission_p -object_id $id -privilege $privilege"
        return [::xo::cc permission -object_id $id -privilege $privilege]
      }
    }
    return 0
  }

  Policy instproc check_permissions {object method} {
    set allowed 0
    foreach class [concat [$object info class] [[$object info class] info heritage]] {
      set c [self]::[namespace tail $class]
      if {![my isclass $c]} continue
      set key require_permission($method)
      if {[$c exists $key]} {
        set permission [$c set $key]
        my log "checking $permission for $c $key"
        switch $permission {
          none  {set allowed 1; break}
          login {auth::require_login; set allowed 1; break}
          swa   {
            set allowed [acs_user::site_wide_admin_p]
            if {!$allowed} {
              ad_return_warning "Insufficient Permissions" \
                  "Only side wide admins are allowed for this operation!"
              ad_script_abort
            }
          }
          default {
            foreach cond_permission $permission {
              my log "--c check $cond_permission"
              switch [llength $cond_permission] {
                3 {foreach {condition attribute privilege} $cond_permission break
                  if {[eval $object condition $method $condition]} break
                }
                2 {foreach {attribute privilege} $cond_permission break
                  break
                }
              }
            }
            set id [$object set $attribute]
            #my log "--c require_permission -object_id $id -privilege $privilege"
            set p [::xo::cc permission -object_id $id -privilege $privilege]
            if {!$p} {
              ns_log notice "permission::require_permission: [::xo::cc user_id]doesn't \
		have $privilege on object $id"
              ad_return_forbidden  "Permission Denied"  "<blockquote>
  You don't have permission to $privilege [$object name].
</blockquote>"
              ad_script_abort
            }
            #permission::require_permission -object_id $id -privilege $privilege
            set allowed 1
            break
          }
        }
      }
    }
    return $allowed
  }



  Policy policy1 -contains {
  
    Class Package -array set require_permission {
      reindex            swa
      rss                none
      delete             {{id admin}}
      edit-new           {{{has_class ::xowiki::Object} id admin} {id create}}
    }
    
    Class Page -array set require_permission {
      view               {{package_id read}}
      revisions          {{package_id write}}
      edit               {{package_id write}}
      make-live-revision {{package_id write}}
      delete-revision    {{package_id admin}}
      delete             {{package_id admin}}
      save-tags          login
      popular-tags       login
    }

    Class Object -array set require_permission {
      edit               {{package_id admin}}
    }
    Class File -array set require_permission {
      download           {{package_id read}}
    }
  }


  Policy policy2 -contains {
    #
    # we require side wide admin rights for deletions
    #

    Class Package -array set require_permission {
      reindex            {{id admin}}
      rss                none
      delete             swa
      edit-new           {{{has_class ::xowiki::Object} id admin} {id create}}
    }
    
    Class Page -array set require_permission {
      view               {{package_id read}}
      revisions          {{package_id write}}
      edit               {{package_id write}}
      make-live-revision {{package_id write}}
      delete-revision    swa
      delete             swa
      save-tags          login
      popular-tags       login
    }

    Class Object -array set require_permission {
      edit               {{package_id admin}}
    }
    Class File -array set require_permission {
      download           {{package_id read}}
    }
  }
  
  Policy policy3 -contains {
    #
    # we require side wide admin rights for deletions
    # we perform checking on item_ids for pages. 
    #

    Class Package -array set require_permission {
      reindex            {{id admin}}
      rss                none
      delete             swa
      edit-new           {{{has_class ::xowiki::Object} id admin} {id create}}
    }
    
    Class Page -array set require_permission {
      view               {{item_id read}}
      revisions          {{item_id write}}
      edit               {{item_id write}}
      make-live-revision {{item_id write}}
      delete-revision    swa
      delete             swa
      save-tags          login
      popular-tags       login
    }

    Class Object -array set require_permission {
      edit               {{package_id admin}}
    }
    Class File -array set require_permission {
      download           {{package_id read}}
    }
  }
  
  
}

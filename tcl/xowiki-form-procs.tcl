ad_library {
    XoWiki - form classes

    @creation-date 2006-04-10
    @author Gustaf Neumann
    @cvs-id $Id$
}

namespace eval ::xowiki {

  #
  # Application specific forms
  #

  Class create WikiForm -superclass ::Generic::Form \
      -parameter {
	{field_list {item_id name title creator text description nls_language}}
	{f.item_id
	  {item_id:key}}
	{f.name
	  {name:text {label #xowiki.name#} {html {size 80}} }}
	{f.title
	  {title:text {label #xowiki.title#} {html {size 80}} }}
	{f.creator
	  {creator:text,optional {label #xowiki.creator#}  {html {size 80}} }}
	{f.text
	  {text:richtext(richtext),nospell,optional
	    {label #xowiki.content#}
	    {options {editor xinha plugins {
	      GetHtml CharacterMap ContextMenu FullScreen InsertAnchor
	      ListType TableOperations EditTag LangMarks Abbreviation OacsFs
	    } height 350px 
            }}
	    {html {rows 15 cols 50 style {width: 100%}}}}
	}
	{f.description
	  {description:text(textarea),nospell,optional 
	    {label #xowiki.description#} {html {cols 80 rows 2}}}
	}
	{f.nls_language
	  {nls_language:text(select),optional {label #xowiki.Language#}
	    {options \[xowiki::locales\]}}}
	{validate
	  {{name {\[::xowiki::validate_name\]} {Another item with this name exists \
		already in this folder}}}}
	{with_categories true}
	{submit_link "view"}
	{folderspec ""}
      }


  WikiForm instproc mkFields {} {
    my instvar data
    set __fields ""
    foreach __field [my field_list] {
      set __spec [my set f.$__field]
      if {[string first "richtext" [lindex $__spec 0]] > -1} {
	# we have a richtext widget; get special configuration is specified
	set __spec [$data get_rich_text_spec $__field $__spec]
	if {[my folderspec] ne ""} {
	  # append the folder spec to its options
	  set __newspec [list [lindex $__spec 0]]
	  foreach __e [lrange $__spec 1 end] {
	    foreach {__name __value} $__e break
	    if {$__name eq "options"} {eval lappend __value [my folderspec]}
	    lappend __newspec $__name $__value
	  }
	  my log "--F rewritten spec is '$__newspec'"
	  set __spec $__newspec
	}
	# ad_form does a subst. escape esp. the javascript stuff
	set __spec [string map {\[ \\[ \] \\] \$ \\$ \\ \\\\} $__spec]
      }
      #my log "--F field <$__field> = $__spec"
      append __fields [list $__spec] \n
    }
    my set fields $__fields
  }

  proc ::xowiki::locales {} {
    set locales [lang::system::get_locales]
    set defpos [lsearch $locales [lang::conn::locale]]
    set locales [linsert [lreplace $locales $defpos $defpos] 0 \
		     [lang::conn::locale]]
    foreach l $locales {lappend lpairs [list $l $l]}
    return $lpairs
  }

  proc ::xowiki::page_templates {} {
    ::xowiki::f1 instvar data folder_id  ;# form has to be named ::xowiki::f1
    # transitional code begin
    set object_type [[$data info class] object_type]
    if {[string match "::xowiki::*" $object_type]} {
      set templateclass ::xowiki::PageTemplate
    } else {
      set templateclass ::PageTemplate
    }
    # transitional code end
    set q [$templateclass instance_select_query \
	       -folder_id $folder_id \
	       -select_attributes {name}]
    db_foreach get_page_templates $q {
      lappend lpairs [list $name $item_id]
    } if_no_rows {
      lappend lpairs [list "(No Page Template available)" ""]
    }
    return $lpairs
  }

  proc ::xowiki::validate_name {} {
    upvar name name nls_language nls_language folder_id folder_id
    if {![regexp {^..:} $name]} {
      if {$nls_language eq ""} {set nls_language [lang::conn::locale]}
      set name [string range $nls_language 0 1]:$name
    }
    set subst_blank_in_name [$folder_id get_payload subst_blank_in_name]
    if {$subst_blank_in_name == 1} {
      regsub -all " " $name "_" name
    }
    if {[ns_set get [ns_getform] __new_p] 
	|| [ns_set get [ns_getform] __object_name] ne $name
      } {
      return [expr {[CrItem lookup -name $name -parent_id $folder_id] == 0}]
    }
    return 1
  }

  WikiForm instproc handle_enhanced_text_from_form {} {
    my instvar data
    array set __tmp [ns_set array [ns_getform]]
    if {[info exists __tmp(text.format)]} {	
      $data set mime_type $__tmp(text.format)
    }
  }
  WikiForm instproc update_references {} {
    my instvar data
    if {![my istype PageInstanceForm]} {
      ### danger: update references does an ad_eval, which breaks the  [template::adp_level]
      ### ad_form! don't do it in pageinstanceforms.
      $data render_adp false
      $data render -update_references
    }
    #
    # delete the link cache entries for this item 
    # could be made more intelligent to delete entries is more rare cases, like
    # in case the file was renamed
    my instvar folder_id
    #ns_log notice "--F folder_id=$folder_id"
    ##### why is ns_cache names xowiki_cache *pattern*   not working???
    foreach entry [ns_cache names xowiki_cache] {
      if {[string match link-*-$folder_id $entry]} {
	array set tmp [ns_cache get xowiki_cache $entry]
	#ns_log notice "--F item_id [$data set item_id] tmp(item_id) = $tmp(item_id)"
	if {$tmp(item_id) == [$data set item_id]} {
	  ns_cache flush xowiki_cache $entry
	}
      }
    }
    ### provide a nice link
    #my set submit_link [::xowiki::Page pretty_link \
			    -package_id [$data set parent_id] \
			    [$data set name]]
  }

  WikiForm instproc new_request {} {
    my instvar data
    $data set creator [$data get_name [ad_conn user_id]]
    my log "--F setting creator to [$data get_name [ad_conn user_id]]"
    next
  }

  WikiForm instproc edit_request args {
    my instvar data
    if {[$data set creator] eq ""} {
      $data set creator [$data get_name [ad_conn user_id]]
    }
    next
  }

  WikiForm instproc new_data {} {
    my handle_enhanced_text_from_form
    set item_id [next]
    my update_references
    return $item_id
  }

  WikiForm instproc edit_data {} {
    my handle_enhanced_text_from_form
    set item_id [next]
    my update_references
    return $item_id
  }

  #
  # PlainWiki Form
  #

  Class create PlainWikiForm -superclass WikiForm \
      -parameter {
	{f.text
	  {text:text(textarea),nospell,optional
	    {label #xowiki.content#}
	    {html {cols 80 rows 10}}}}
  }

  #
  # Object Form
  #

  Class create ObjectForm -superclass PlainWikiForm \
      -parameter {
	{f.text
	  {text:text(textarea),nospell,optional
	    {label #xowiki.content#}
	    {html {cols 80 rows 15}}}}
	{with_categories  false}
      }

  ObjectForm instproc init {} {
    my instvar data
    if {[$data exists name]} {
      # don't call validate on the folder object, don't let people change its name
      set name [$data set name]
      if {$name eq "::[$data set parent_id]"} {
	my f.name  {name:text(inform) {label #xowiki.name#}}
	my validate {{name {1} {dummy}} }
	#my log "--e don't validate folder id - parent_id = [$data set parent_id]"
      }
    }
    next
  }

  ObjectForm instproc new_request {} {
    my instvar data
    permission::require_permission \
	-party_id [ad_conn user_id] -object_id [$data set parent_id] \
	-privilege "admin"
    next
  }

  ObjectForm instproc edit_request {item_id} {
    my instvar data
    my log "--e setting f.name"
    my f.name {{name:text {label #xowiki.name#}}}
    permission::require_permission \
	-party_id [ad_conn user_id] -object_id [$data set parent_id] \
	-privilege "admin"
    next
  }

  ObjectForm instproc edit_data {} {
    [my data] initialize_loaded_object
    next
  }

  #
  # PageInstance Forms
  #

  Class create PageInstanceForm -superclass WikiForm \
      -parameter {
	{field_list {item_id name page_template description nls_language}}
	{f.page_template
	  {page_template:text(select)
	    {label "Page Template"}
	    {options \[xowiki::page_templates\]}}
	}
	{with_categories  false}
      }
  PageInstanceForm instproc set_submit_link_edit {} {
    my instvar folder_id data
    set object_type [[$data info class] object_type]
    #my log "-- data=$data cl=[$data info class] ot=$object_type"
    set item_id [$data set item_id]
    set page_template [ns_set get [ns_getform] page_template]
    set f [ns_getform]
    if {[ns_set find $f return_url]} {set return_url [ns_set get $f return_url]}
    my submit_link [export_vars -base edit {folder_id object_type item_id page_template return_url}]
    my log "-- submit_link = [my submit_link]"
  }

  PageInstanceForm instproc new_data {} {
    my instvar data
    set item_id [next]
    my set_submit_link_edit
    return $item_id
  }

  PageInstanceForm instproc edit_data {} {
    set item_id [next]
    #my log "-- edit_data item_id=$item_id"
    return $item_id
  }

  Class create PageInstanceEditForm -superclass WikiForm \
      -parameter {
 	{field_list {item_id name title creator page_template description nls_language}}
 	{f.name           {name:text(inform)}}
 	{f.page_template  {page_template:text(hidden)}}
 	{f.nls_language   {nls_language:text(hidden)}}
	{with_categories  true}
	{textfieldspec    {text(textarea),nospell {html {cols 60 rows 5}}}}
      }

  PageInstanceEditForm instproc new_data {} {
    set __vars {folder_id item_id page_template return_url}
    set object_type [[[my set data] info class] object_type]
    #my log "-- cl=[[my set data] info class] ot=$object_type $__vars"
    foreach __v $__vars {set $__v [ns_queryget $__v]}
    set item_id [next]
    my submit_link [export_vars -base edit $__vars]
    my log "-- submit_link = [my submit_link]"
    return $item_id
  }

  PageInstanceEditForm instproc edit_request {item_id} {
    my log "-- "
    my instvar page_instance_form_atts data
    next
    array set __ia [$data set instance_attributes]
    foreach var $page_instance_form_atts {
      if {[info exists __ia($var)]} {my var $var [list $__ia($var)]}
    }
  }


  PageInstanceEditForm instproc edit_data {} {
    my log "-- "
    my instvar page_instance_form_atts data
    array set __ia [$data set instance_attributes]
    foreach var $page_instance_form_atts {
      set __ia($var) [my var $var]
    }
    my log "-- set instance_attributes [array get __ia]"
    $data set instance_attributes [array get __ia]
    set item_id [next]
    my log "-- edit_data item_id=$item_id"
    return $item_id
  }

  PageInstanceEditForm instproc init {} {
    my instvar data page_instance_form_atts
    set item_id [ns_queryget item_id]
    set page_template [ns_queryget page_template]
    if {$page_template eq ""} {
      set page_template [$data set page_template]
      #my log  "-- page_template = $page_template"
    }
    #my log  "-- calling page_template = $page_template"
    set template [::Generic::CrItem instantiate -item_id $page_template]
    $template volatile
    set dont_edit [concat [[$data info class] edit_atts] [list title] \
		       [::Generic::CrClass set common_query_atts]]
    set page_instance_form_atts [list]
    foreach {_1 _2 var} [regexp -all -inline \
			     [template::adp_variable_regexp] \
			     [$template set text]] {
      if {[lsearch $dont_edit $var] == -1} {lappend page_instance_form_atts $var}
    }

    foreach __var $page_instance_form_atts {
      my lappend field_list $__var
      my set f.$__var "$__var:[$data get_field_type $__var $template [my textfieldspec]]"
    }
    next
    #my log "--fields = [my fields]"
  }

}

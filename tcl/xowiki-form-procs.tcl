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
	{field_list {item_id name page_order title creator text description nls_language}}
	{f.item_id {item_id:key}}
	{f.name "="}
	{f.page_order "="}
        {f.title "="}
        {f.creator "="}
	{f.text "= richtext,editor=xinha"}
        {f.description "="}
        {f.nls_language "="}
        {validate
          {{name {\[::xowiki::validate_name\]} {Another item with this name exists \
                already in this folder}}}}
        {with_categories true}
        {submit_link "view"}
        {folderspec ""}
        {autoname 0}
      } -ad_doc {
        Form Class for XoWiki Pages. 
          
	You can manipulate the form elements shown by editing the field_list. 
	The following elements are mandatory in field_list
        and should never be left out:
          <ul>
          <li>name
          <li>item_id
          </ul>
          
      }

  WikiForm instproc mkFields {} {
    my instvar data autoname
    set __fields ""
    set field_list [my field_list]

    set show_page_order [[$data package_id] show_page_order]
    if {!$show_page_order} { my f.page_order "= hidden" } 
    if {$autoname}         { my f.name       "= hidden,optional"}
    set form_fields [list]

    foreach __field $field_list {

      # if there is no field spec, use the default from the slot definitions
      set __spec  [expr {[my exists f.$__field] ? [my set f.$__field] : "="}]
      set __wspec [lindex $__spec 0]
      #my msg "$__field wspec=$__wspec, spec=$__spec"

      # check first if we have widget_specs.
      # TODO: this part is likely to be removed in the future.
      set s [$data get_rich_text_spec $__field ""]
      if {$s ne ""} {
	set __spec $s
	set __wspec [lindex $__spec 0]
	# old style folder spec substituion. ugly.
        if {[my folderspec] ne ""} {
          # append the folder spec to its options
          set __newspec [list $__wspec]
          foreach __e [lrange $__spec 1 end] {
            foreach {__name __value} $__e break
            if {$__name eq "options"} {eval lappend __value [my folderspec]}
            lappend __newspec [list $__name $__value]
          }
          #my log "--F rewritten spec is '$__newspec'"
          set __spec $__newspec
        }
      } elseif {[lindex $__wspec 0] eq "="} {
	# 
	# get the information from the attribute definitions & given specs
	#
        set f [$data create_form_field \
                   -name $__field \
                   -slot [$data find_slot $__field] \
                   -spec [lindex $__spec 1] \
                  ]

        if {[$f istype ::xowiki::FormField::richtext] &&
            [my folderspec] ne ""} {
          # insert the folder id into the spec for the 
          # oacsfs plugin to access the correct filestore instance
          foreach {key value} [my folderspec] break
          $f $key $value
        }

        set __spec ${__field}:[$f asWidgetSpec]
        set __wspec [lindex $__spec 0]
        lappend form_fields $f
      }

      if {[string first "richtext" $__wspec] > -1} {
        # ad_form does a subst, therefore escape esp. the javascript stuff
        set __spec [string map {\[ \\[ \] \\] \$ \\$ \\ \\\\} $__spec]
      }

      #my msg "--F field <$__field> = $__spec"
      append __fields [list $__spec] \n
    }

    # setting form fields for later use in validator
    # $data show_fields $form_fields
    my set form_fields $form_fields

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
    set q [::xowiki::PageTemplate instance_select_query \
               -folder_id $folder_id \
               -with_subtypes false \
               -select_attributes {name}]
    db_foreach [my qn get_page_templates] $q {
      lappend lpairs [list $name $item_id]
    } if_no_rows {
      lappend lpairs [list "(No Page Template available)" ""]
    }
    return $lpairs
  }

  #
  # todo: this should be OO-ified -gustaf
  proc ::xowiki::validate_file {} {
    my instvar data
    my get_uploaded_file
    upvar title title
    if {$title eq ""} { set title [$data set upload_file] }
    # my log "--F validate_file returns [$data exists import_file]"
    return [$data exists import_file]
  }

  proc ::xowiki::guesstype {fn} {
    set mime [ns_guesstype $fn]
    if {$mime eq "*/*"} {
      # ns_guesstype was failing
      switch [file extension $fn] {
        .mp3 {set mime audio/mpeg}
        .cdf {set mime application/x-netcdf}
        .flv {set mime video/x-flv}
      }
    }
    return $mime
  }

  proc ::xowiki::validate_duration {} {
    upvar duration duration
    my instvar data 
    $data instvar package_id
    if {[$data istype ::xowiki::PodcastItem] && $duration eq "" && [$data exists import_file]} {
      set filename [expr {[$data exists full_file_name] ? [$data full_file_name] : [$data set import_file]}]
      set ffmpeg [$package_id get_parameter "ffmpeg" "/usr/bin/ffmpeg"]
      if {[file exists $ffmpeg]} {
        catch {exec $ffmpeg -i $filename} output
        if {[info exists output]} {
          regexp {Duration: +([0-9:.]+)[ ,]} $output _ duration
        }
      }
    }
    return 1
  }


  proc ::xowiki::validate_name {} {
    upvar name name nls_language nls_language
    my instvar data

    set old_name [::xo::cc form_parameter __object_name ""]
    if {$name eq $old_name && $name ne ""} {
      # do not change names, which are already validated;
      # otherwise, autonamed entries might get an unwanted en:prefix
      return 1
    }
    # my log "--F validate_name data=[my exists data]"
    $data instvar package_id
    if {[$data istype ::xowiki::File] && [$data exists mime_type]} {
      #my log "--mime validate_name data=[my exists data] MIME [$data set mime_type]"
      set name [$data complete_name $name [$data set upload_file]]
    } else {
      if {![regexp {^..:} $name]} {
        if {![info exists nls_language]} {
          set nls_language [lang::conn::locale]
        }
        set name [$data complete_name $name $nls_language]
      }
    }
    set name [::$package_id normalize_name $name]

    # check, if we try to create a new item with an existing name
    if {[$data form_parameter __new_p 0]
        || [$data form_parameter __object_name] ne $name
      } {
      set folder_id [$data parent_id]
      return [expr {[CrItem lookup -name $name -parent_id $folder_id] == 0}]
    }
    return 1
  }


  proc ::xowiki::validate_form_constraints {} {
    upvar form_constraints form_constraints
    my instvar data
    set f [$data lookup_form_field -name form_constraints [my set form_fields]]
    $f value $form_constraints
    set validation_error [$f validate $data]
    if {$validation_error ne ""} {
      util_user_message -message "Error in form constraints: $validation_error"
      set success 0
    } else {
      set success 1
    }
    return $success
  }




  WikiForm instproc data_from_form {{-new 0}} {
    my instvar data
    if {[$data exists_form_parameter text.format]} {
      $data set mime_type [$data form_parameter text.format]
    }
    if {$new && [[$data set package_id] get_parameter production_mode 0]} {
      $data set publish_status production
    }
    upvar #[template::adp_level] page_order page_order
    if {[info exists page_order] && $page_order ne ""} {
      set page_order [string trim $page_order " ."]
    }
  }
  WikiForm instproc update_references {} {
    my instvar data folder_id
    if {![my istype PageInstanceForm]} {
      ### danger: update references does an ad_eval, which breaks the [template::adp_level]
      ### ad_form! don't do it in pageinstanceforms.
      $data render_adp false
      $data render -update_references
    }
    # Delete the link cache entries for this entry.
    # The logic could be made more intelligent to delete entries is more rare cases, like
    # in case the file was renamed, but this is more bullet-proove.
    #
    # In case "ns_cache names xowiki_cache *pattern*" is not working on your installation;
    #    upgrade ns_cache from cvs or use
    #    foreach entry [lsearch -inline -all [ns_cache names xowiki_cache] link-*-$folder_id] 
    foreach entry [ns_cache names xowiki_cache link-*-$folder_id] {
      array set tmp [ns_cache get xowiki_cache $entry]
      if {$tmp(item_id) == [$data set item_id]} {
        ns_cache flush xowiki_cache $entry
      }
    }
    if {![$data istype ::xowiki::Object] &&
        ![$data istype ::xowiki::PageTemplate] } {
      if {[$data istype ::xowiki::PageInstance]} {
        if {[$data set instance_attributes] ne ""} {
          # fieldless page instances are not notified. problem?
          # my log "--i instance_attributes = <[$data set instance_attributes]>"
          ::xowiki::notification::do_notifications -page $data
        }
      } else {
        ::xowiki::notification::do_notifications -page $data
      }
    }

    #my log "v=[ad_acs_version] 5.2] compare: [apm_version_names_compare [ad_acs_version] 5.2]"
    if {[apm_version_names_compare [ad_acs_version] 5.3.0d4] == 1} {
      application_data_link::update_links_from \
          -object_id [$data set item_id] \
          -text [$data set text]
    }
  }
  
    
  WikiForm instproc new_request {} {
    my instvar data
    #
    # get the defaults from the slots and set it in the data.
    # This should not be necessary with xotocl 1.6.*
    #
    foreach f [my field_list] {
      set s [$data find_slot $f] 
      if {$s ne "" && [$s exists default] && [$s default] ne ""} {
        #my msg "new_request $f default = '[$s default]'"
        $data set $f [$s default]
      }
    }
    # 
    # set the following defaults manually
    #
    $data set creator [::xo::get_user_name [::xo::cc user_id]]
    $data set nls_language [ad_conn locale]
    next
  }

  WikiForm instproc edit_request args {
    my instvar data
    if {[$data set creator] eq ""} {
      $data set creator [::xo::get_user_name [::xo::cc user_id]]
    }
    next
  }

  WikiForm instproc new_data {} {
    my instvar data
    my data_from_form -new 1 
    $data set __autoname_prefix [string range [$data set nls_language] 0 1]:
    set item_id [next]
    $data set creation_user [::xo::cc user_id]
    my update_references
    return $item_id
  }

  WikiForm instproc edit_data {} {
    my data_from_form -new 0
    set item_id [next]
    my update_references
    return $item_id
  }

  WikiForm instproc after_submit {item_id} {
    set link [my submit_link]
    if {$link eq "."} {
      my instvar data
      # we can determine submit link only after nls_langauge 
      # is returned from the user
      my submit_link [[$data package_id] pretty_link [$data name]]
    }
    next
  }
  #
  # PlainWiki Form
  #

  Class create PlainWikiForm -superclass WikiForm \
      -parameter {
        {f.text "= textarea,cols=80,rows=10"}
      }

  #
  # File Form
  #

  Class create FileForm -superclass WikiForm \
      -parameter {
        {html { enctype multipart/form-data }} \
        {field_list {item_id name page_order text title creator description}}
        {f.name  "= optional,help_text=#xowiki.File-name-help_text#"}
        {f.title "= optional"}
        {f.text
          {upload_file:file(file) 
            {label #xowiki.content#}
            {html {size 30}} }}
        {validate {
          {upload_file {\[::xowiki::validate_file\]} {For new entries, \
                                                          a upload file must be provided}}
          {name {\[::xowiki::validate_name\]} {Another item with this name exists \
                                                   already in this folder}}
          }}
        }


  FileForm instproc get_uploaded_file {} {
    my instvar data
    #my log "--F... [ns_conn url] [ns_conn query] form vars = [ns_set array [ns_getform]]"
    set upload_file [$data form_parameter upload_file]
    # my log "--F... upload_file = $upload_file"
    if {$upload_file ne "" && $upload_file ne "{}"} {
      $data set upload_file  $upload_file
      $data set import_file [$data form_parameter upload_file.tmpfile]
      set mime_type   [$data form_parameter upload_file.content-type]
      if {$mime_type eq "application/octet-stream"} {
        set guessed_mime_type [::xowiki::guesstype $upload_file]
        my msg guess=$guessed_mime_type
        if {$guessed_mime_type ne "*/*"} {
          set mime_type $guessed_mime_type
        }
      }
      $data set mime_type $mime_type
    } elseif {[$data exists name]} {
      # my log "--F no upload_file provided [lsort [$data info vars]]"
      if {[$data exists mime_type]} {
        my log "--mime_type=[$data set mime_type]"
        #my log "   text=[$data set text]"
        regexp {^[^:]+:(.*)$} [$data set name] _ upload_file
        $data set upload_file $upload_file
        $data set import_file [$data full_file_name]
        # my log "--F upload_file $upload_file  import_file [$data full_file_name]"
        #my log "   import_type=[$data set import_file]"
      } 
    } else {
      # my log "--F no name and no upload file"
      $data set upload_file ""
    }
  }
  FileForm instproc new_data {} {
    #my get_uploaded_file
    return [next]
  }
  FileForm instproc edit_data {} {
    #my get_uploaded_file
    return [next]
  }

#         {f.pub_date 
# 	  {pub_date:date,optional {format "YYYY MM DD HH24 MI"} {html {id date}}
# 	    {after_html {<input type="button" 
# 	      style="height:23px; width:23px; background: url('/resources/acs-templating/calendar.gif');" 
# 	      onclick ="return showCalendarWithDateWidget('date', 'y-m-d');" /> Y-M-D}
# 	    }}
# 	}

  Class create PodcastForm -superclass FileForm \
      -parameter {
        {html { enctype multipart/form-data }} \
        {field_list {item_id name page_order text title subtitle creator pub_date duration keywords 
	  description}}
        {validate {
          {upload_file {\[::xowiki::validate_file\]} {For new entries, \
                                                          a upload file must be provided}}
          {name {\[::xowiki::validate_name\]} {Another item with this name exists \
                                                   already in this folder}}
          {duration {\[::xowiki::validate_duration\]} {Check duration and provide default}}
          }}
      }

#	    {help_text {E.g. 9:16 means 9 minutes 16 seconds (if ffmpeg is installed and configured, it will get the value automatically)}}

  PodcastForm instproc to_timestamp {widgetinfo} {
    if {$widgetinfo ne ""} {
      foreach {y m day hour min} $widgetinfo break
      set t [clock scan "${hour}:$min $m/$day/$y"]
      return [clock format $t]
    }
    return ""
  }
  PodcastForm instproc to_timeinfo {timestamp} {
    set t [clock scan $timestamp]
    return "[clock format $t -format {%Y %m %d %H %M}] {} {YY MM DD HH24 MI}"
  }

  PodcastForm instproc new_data {} {
    set pub_date [my var pub_date]
    my var pub_date [list [my to_timestamp $pub_date]]
    return [next]
  }
  PodcastForm instproc edit_data {} {
    set pub_date [my var pub_date]
    my var pub_date [list [my to_timestamp $pub_date]]
    return [next]
  }

  PodcastForm instproc new_request {} {
    my instvar data
    $data set pub_date [my to_timeinfo [clock format [clock seconds]  -format "%y-%m-%d %T"]]
    next
  }
  PodcastForm instproc edit_request {item_id} {
    my instvar data
    $data set pub_date [my to_timeinfo [$data set pub_date]]
    next
  }


  #
  # Object Form
  #

  Class create ObjectForm -superclass PlainWikiForm \
      -parameter {
        {f.text "= textarea,cols=80,rows=15"}
        {with_categories  false}
      }

  ObjectForm instproc init {} {
    my instvar data
    if {[$data exists name]} {
      # don't call validate on the folder object, don't let people change its name
      set name [$data set name]
      if {$name eq "::[$data set parent_id]"} {
        my f.name  "= inform,help_text="
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
    #my f.name {{name:text {label #xowiki.Page-name#}}}
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
  # PageTemplateForm
  #
  Class create PageTemplateForm -superclass WikiForm \
      -parameter {
	{field_list {
	  item_id name page_order title creator text anon_instances 
          description nls_language
	}}
      }

  #
  # PageInstance Forms
  #

  Class create PageInstanceForm -superclass WikiForm \
      -parameter {
        {field_list {item_id name page_order page_template description nls_language}}
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
    set page_template [$data form_parameter page_template]
    if {[$data exists_query_parameter return_url]} {
      set return_url [$data query_parameter return_url]
    }
    set link [::[$data set package_id] pretty_link [$data set name]]
    my submit_link [export_vars -base $link {{m edit} page_template return_url item_id}]
    # my log "-- submit_link = [my submit_link]"
  }

  PageInstanceForm instproc new_data {} {
    my instvar data
    set item_id [next]
    my set_submit_link_edit
    return $item_id
  }

  PageInstanceForm instproc edit_data {} {
    return [next]
  }

  Class create PageInstanceEditForm -superclass WikiForm \
      -parameter {
        {field_list_top    {item_id name page_order title creator}}
        {field_list_bottom {page_template description nls_language}}
        {f.name            "= inform"}
        {f.page_template   {page_template:text(hidden)}}
        {f.nls_language    {nls_language:text(hidden)}}
        {with_categories   true}
        {textfieldspec     {text(textarea),nospell {html {cols 60 rows 5}}}}
      }

  PageInstanceEditForm instproc new_data {} {
    my instvar data
    set __vars {folder_id item_id page_template return_url}
    set object_type [[$data info class] object_type]
    #my log "-- cl=[[my set data] info class] ot=$object_type $__vars"
    foreach __v $__vars {set $__v [$data from_parameter $__v] ""}
    set item_id [next]

    set link [::[$data set package_id] pretty_link [$data set name]]
    my submit_link [export_vars -base $link {{m edit} $__vars}]
    # my log "-- submit_link = [my submit_link]"
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
    $data set instance_attributes [array get __ia]
    set item_id [next]
    my log "-- edit_data item_id=$item_id"
    return $item_id
  }

  PageInstanceEditForm instproc init {} {
    my instvar data page_instance_form_atts
    set item_id [$data form_parameter item_id]
    #
    # make sure to have page template object loaded
    #
    set page_template_id [$data form_parameter page_template ""]
    if {$page_template_id eq ""} {
      set page_template_id [$data set page_template]
    }
    set template [::Generic::CrItem instantiate -item_id $page_template_id]
    $template destroy_on_cleanup
    set dont_edit [concat [[$data info class] edit_atts] [list title] \
                       [::Generic::CrClass set common_query_atts]]

    set category_spec [$data get_short_spec @categories]
    foreach f [split $category_spec ,] {
      if {$f eq "off"} {my set with_categories false}
    }

    #
    # compute list of form instance attributes
    #
    set page_instance_form_atts [list]
    foreach {var _} [$data template_vars [$template set text]] {
      if {[lsearch $dont_edit $var] == -1} {lappend page_instance_form_atts $var}
    }
    my set field_list [concat [my field_list_top] $page_instance_form_atts [my field_list_bottom]]

    #
    # get widget specs from folder. 
    # All other specs are taken form attributes or form constraints.
    # The widget_spec functionality might be deprecated in the future.
    #
    foreach __var $page_instance_form_atts {
      set spec [$data widget_spec_from_folder_object $__var [$template set name]]
      if {$spec ne ""} {
        my set f.$__var "$__var:$spec"
      }
    }

    my edit_page_title [$data get_from_template title]
    next
    #my log "--fields = [my fields]"
  }

  proc ::xowiki::validate_form_text {} {
    upvar text text
    if {$text eq ""} { return 1 }
    if {[llength $text] != 2} { return 0 }
    foreach {content mime} $text break
    if {$content eq ""} {return 1}
    set clean_content $content
    regsub -all "<br */?>" $clean_content "" clean_content
    regsub -all "</?p */?>" $clean_content "" clean_content
    #ns_log notice "--validate_form_content '$content' clean='$clean_content', \
    #	stripped='[string trim $clean_content]'"
    if {[string trim $clean_content] eq ""} { set text [list "" $mime]}
    #my msg "final text='$text'"
    return 1
  }

  proc ::xowiki::validate_form_form {} {
    upvar form form
    if {$form eq ""} {return 1}
    dom parse -simple -html [lindex $form 0] doc
    $doc documentElement root
    return [expr {[$root nodeName] eq "form"}]
  }

  Class create FormForm -superclass ::xowiki::PageTemplateForm \
    -parameter {
      {field_list {item_id name page_order title creator text form form_constraints 
        anon_instances description nls_language}}
      {f.text "= richtext,height=150px,label=#xowiki.Form-template#"}
      {f.form "= richtext,height=150px"}
      {f.form_constraints "="}
      {validate {
        {name {\[::xowiki::validate_name\]} {Another item with this name exists \
                                                 already in this folder}}
        {text {\[::xowiki::validate_form_text\]} {Form must contain a valid template}}
        {form {\[::xowiki::validate_form_form\]} {Form must contain an HTML form}}
        {form_constraints {\[::xowiki::validate_form_constraints\]} {Invalid form constraints}}
      }}
    }
  
  FormForm instproc new_data {} {
    my instvar data
    set item_id [next]
    
    # provide unique ids and names, if form is provided
#     set form [$data set form]
#     if {$form ne ""} {
#       dom parse -simple -html [lindex $form 0] doc
#       $doc documentElement root
#       set id ID$item_id
#       $root setAttribute id $id
#       set fields [$root selectNodes "//*\[@name != ''\]"]
#       foreach field $fields {
#         $field setAttribute name $id.[$field getAttribute name]
#       }
#       # updating is rather crude. we need the item_id in advance to fill it
#       # into the items, but it is returned from saving the file.
#       my log "item_id=$item_id form=[$root asHTML] [$data serialize]"
#       $data update_content [$data revision_id] [list [$root asHTML] [lindex $form 1] ]
#     }
    return $item_id
  }



}

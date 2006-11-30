::xowiki::Package initialize -ad_doc {
  This is the admin page for the package.  It displays all entries
  provides links to create, edit and delete these

  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date Oct 23, 2005
  @cvs-id $Id$

  @param object_type show objects of this class and its subclasses
} -parameter {
  {-object_type:optional}
  {-orderby:optional "last_modified,desc"}
}

set context   [list index]

# if object_type is specified, only list entries of this type;
# otherwise show types and subtypes of $supertype
if {![info exists object_type]} {
  set per_type 0
  set supertype ::xowiki::Page
  set object_types [$supertype object_types]
  set title "List of all kind of [$supertype set pretty_plural]"
  set with_subtypes true
  set object_type $supertype
} else {
  set per_type 1
  set object_types [list $object_type]
  set title "Index of [$object_type set pretty_plural]"
  set with_subtypes false
}

set return_url [expr {$per_type ? [export_vars -base [::$package_id url] object_type] :
                      [::$package_id url]}]
# set up categories
set category_map_url [export_vars -base \
              [site_node::get_package_url -package_key categories]cadmin/one-object \
                          { { object_id $package_id } }]

set actions ""
foreach type $object_types {
  append actions [subst {
    Action new \
        -label "[_ xotcl-core.add [list type [$type pretty_name]]]" \
        -url [export_vars -base [::$package_id package_url] {{edit-new 1} {object_type $type} return_url}] \
        -tooltip  "[_ xotcl-core.add_long [list type [$type pretty_name]]]"
  }]
}

set ::individual_permissions [expr {[$package_id set policy] eq "::xowiki::policy3"}]
set ::with_publish_status 1

TableWidget t1 -volatile \
    -actions $actions \
    -columns {
      ImageField_EditIcon edit -label "" -html {style "padding-right: 2px;"}
      if {$::individual_permissions} {
        ImageField permissions -src /resources/xowiki/permissions.png -width 16 \
            -height 16 -border 0 -title "Manage Individual Permssions for this Item" \
            -alt permsissions -label "" -html {style "padding: 2px;"}
      }
      if {$::with_publish_status} {
	ImageField publish_status -src "" -width 8 \
            -height 8 -border 0 -title "Toggle Publish Status" \
            -alt "publish status" -label [_ xowiki.publish_status] -html {style "padding: 2px;"}
      }
      AnchorField name -label [_ xowiki.name] -orderby name
      Field object_type -label [_ xowiki.page_type] -orderby object_type 
      Field size -label "Size" -orderby size -html {align right}
      Field last_modified -label "Last Modified" -orderby last_modified
      Field mod_user -label "By User" -orderby mod_user
      ImageField_DeleteIcon delete -label "" ;#-html {onClick "return(confirm('Confirm delete?'));"}
    }

foreach {att order} [split $orderby ,] break
t1 orderby -order [expr {$order eq "asc" ? "increasing" : "decreasing"}] $att

set order_clause "order by ci.name"
# -page_size 10
# -page_number 1

db_foreach instance_select \
    [$object_type instance_select_query \
         -folder_id [::$package_id folder_id] \
         -with_subtypes $with_subtypes \
         -select_attributes [list revision_id content_length creation_user \
                  "to_char(last_modified,'YYYY-MM-DD HH24:MI:SS') as last_modified"] \
         -order_clause $order_clause \
        ] {
          set page_link [::$package_id pretty_link $name]

          t1 add \
              -name $name \
              -object_type $object_type \
              -name.href $page_link \
              -last_modified $last_modified \
              -size [expr {$content_length ne "" ? $content_length : 0}]  \
              -edit.href [export_vars -base $page_link {{m edit} return_url}] \
              -mod_user [::xo::get_user_name $creation_user] \
              -delete.href [export_vars -base  [$package_id package_url] {{delete 1} item_id name return_url}]
          if {$::individual_permissions} {
            # TODO: this should get some architectural support
            [lindex [t1 set __children] end] set permissions.href \
                [export_vars -base permissions {item_id return_url}] 
          }
          if {$::with_publish_status} {
            # TODO: this should get some architectural support
	    if {$publish_status eq "ready"} {
	      set image active.png
	      set state "production"
	    } else {
	      set image inactive.png
	      set state "ready"
	    }
            [lindex [t1 set __children] end] set publish_status.src /resources/xowiki/$image
	    [lindex [t1 set __children] end] set publish_status.href \
		[export_vars -base [$package_id package_url]admin/set-publish-state \
		     {state revision_id return_url}]
          }
        }

set t1 [t1 asHTML]
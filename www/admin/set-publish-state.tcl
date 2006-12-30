::xowiki::Package initialize -ad_doc {
  Changes the publication state of a content item

  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date Nov 16, 2006
  @cvs-id $Id$

  @param object_type 
  @param query
} -parameter {
  {-state:required}
  {-revision_id:required}
  {-return_url "."}
}

set item_id [db_string get_item_id \
                 {select item_id from cr_revisions 
                   where revision_id = :revision_id}]
ns_cache flush xotcl_object_cache ::$item_id
ns_cache flush xotcl_object_cache ::$revision_id

db_0or1row make_live {select content_item__set_live_revision(:revision_id,:state)}

if {$state ne "production"} {
  ::xowiki::notification::do_notifications -revision_id $revision_id
  ::xowiki::datasource $revision_id
}

ad_returnredirect $return_url

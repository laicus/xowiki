ad_library {
    XoWiki - Search Service Contracts

    @creation-date 2006-01-10
    @author Gustaf Neumann
    @cvs-id $Id$
}

namespace eval ::xowiki {}

ad_proc -private ::xowiki::datasource { revision_id } {
    @param revision_id

  returns a datasource for the search package
} {
  ns_log notice "--sc datasource called with revision_id = $revision_id"

  set page [::xowiki::Package instantiate_from_page -revision_id $revision_id]
  $page volatile

  set html [$page render]
  set text [ad_html_text_convert -from text/html -to text/plain -- $html]
  #set text [ad_text_to_html $html]; #this could be used for entity encoded html text in rss entries
  
  #ns_log notice "--sc INDEXING $revision_id -> $text"
  #$page set unresolved_references 0
  $page instvar item_id
  db_dml delete_old_revisions {delete from txt where object_id in \
      (select revision_id from cr_revisions where item_id = :item_id and revision_id != :revision_id)}
  foreach tag {h1 h2 h3 h4 h5 b strong} {
    foreach {match words} [regexp -all -inline "<$tag>(\[^<\]+)</$tag>" $html] {
      foreach w [split $words] {
	if {$w eq ""} continue
	set word($w) 1
      }
    }
  }
  ns_log notice "--sc keywords $revision_id -> [array names word]"

  return [list object_id $revision_id title [$page title] \
	      content $html keywords [array names word] \
	      storage_type text mime text/html \
	      syndication [list \
			link [::xowiki::Page pretty_link -fully_qualified 1 [$page set name]] \
			description $text \
			author [$page set creator] \
			category "" \
			guid "$item_id" \
			pubDate [$page set last_modified]] \
	     ]
}

ad_proc -private ::xowiki::url { revision_id } {
    @param revision_id

    returns a url for a message to the search package
} {
  set page [::xowiki::Package instantiate_from_page -revision_id $revision_id]
  $page volatile
  return [::[$page package_id] url]
}



namespace eval ::xowiki::sc {}

ad_proc -private ::xowiki::sc::register_implementations {} {
    Register the content type fts contract
} {
   acs_sc::impl::new_from_spec -spec {
      name "::xowiki::Page"
      aliases {
	datasource ::xowiki::datasource
	url ::xowiki::url
      }
      contract_name FtsContentProvider
      owner xowiki
    }
    acs_sc::impl::new_from_spec -spec {
      name "::xowiki::PlainPage"
      aliases {
	datasource ::xowiki::datasource
	url ::xowiki::url
      }
      contract_name FtsContentProvider
      owner xowiki
    }
    acs_sc::impl::new_from_spec -spec {
      name "::xowiki::PageInstance"
      aliases {
	datasource ::xowiki::datasource
	url ::xowiki::url
      }
      contract_name FtsContentProvider
      owner xowiki
    }
}

ad_proc -private ::xowiki::sc::unregister_implementations {} {
  acs_sc::impl::delete -contract_name FtsContentProvider -impl_name ::xowiki::Page
  acs_sc::impl::delete -contract_name FtsContentProvider -impl_name ::xowiki::PlainPage
  acs_sc::impl::delete -contract_name FtsContentProvider -impl_name ::xowiki::PageInstance
}



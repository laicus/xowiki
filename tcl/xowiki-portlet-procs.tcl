
namespace eval ::xowiki::portlet {
  Class create ::xowiki::Portlet \
      -superclass ::xo::Context \
      -parameter {{name ""} {title ""} {__decoration "portlet"} {id}}

  ::xowiki::Portlet instproc locale_clause {package_id locale} {
    set default_locale [$package_id default_locale]
    set system_locale ""

    set with_system_locale [regexp {(.*)[+]system} $locale _ locale]
    if {$locale eq "default"} {
      set locale $default_locale
      set include_system_locale 0
    }

    set locale_clause ""    
    if {$locale ne ""} {
      set locale_clause " and r.nls_language = '$locale'" 
      if {$with_system_locale} {
        set system_locale [lang::system::locale -package_id $package_id]
        if {$system_locale ne $default_locale} {
          set locale_clause " and (r.nls_language = '$locale' 
		or r.nls_language = '$system_locale' and not exists
		  (select 1 from cr_items i where i.name = '[string range $locale 0 1]:' || 
		  substring(ci.name,4) and i.parent_id = ci.parent_id))"
        }
      } 
    }

    #my log "--locale $locale, def=$default_locale sys=$system_locale, cl=$locale_clause"
    return [list $locale $locale_clause]
  }

}

namespace eval ::xowiki::portlet {
  #############################################################################
  # dotlrn style portlet decoration for includelets
  #
  Class ::xowiki::portlet::decoration=portlet -instproc render {} {
    my instvar package_id name title
    set class [namespace tail [my info class]]
    set id [expr {[my exists id] ? "id='[my id]'" : ""}]
    set link [expr {[string match "*:*" $name] ? [$package_id pretty_link $name] : ""}]
    return "<div class='$class'><div class='portlet-title'>\
        <span><a href='$link'>$title</a></span></div>\
        <div $id class='portlet'>[next]</div></div>"
  }
  Class ::xowiki::portlet::decoration=plain -instproc render {} {
    set class [namespace tail [my info class]]
    set id [expr {[my exists id] ? "id='[my id]'" : ""}]
    return "<div $id class='$class'>[next]</div>"
  }
}

namespace eval ::xowiki::portlet {
  #############################################################################
  # rss button
  #
  Class create rss-button \
      -superclass ::xowiki::Portlet \
      -parameter {{__decoration plain}}

  rss-button instproc render {} {
    # use "span" to specify parameters to the rss call
    my initialize -parameter {
      {-span "10d"}
    }
    my get_parameters
    return "<a href='[$package_id package_url]?rss=$span' class='rss'>RSS</a>"
  }

  #############################################################################
  # set-parameter "includelet"
  #
  Class create set-parameter \
      -superclass ::xowiki::Portlet \
      -parameter {{__decoration plain}}

  set-parameter instproc render {} {
    my get_parameters
    set pl [my set __caller_parameters]
    if {[llength $pl] % 2 == 1} {
      error "no even number of parameters '$pl'"
    }
    foreach {att value} $pl {
      ::xo::cc set_parameter $att $value
    }
    return ""
  }
}

namespace eval ::xowiki::portlet {
  #############################################################################
  # valid parameters for he categories portlet are
  #     tree_name: match pattern, if specified displays only the trees 
  #                with matching names
  #     no_tree_name: if specified, tree names are not displayed
  #     open_page: name (e.g. en:iMacs) of the page to be opened initially
  #     tree_style: boolean, default: true, display based on mktree

  Class create categories \
      -superclass ::xowiki::Portlet \
      -parameter {{title "Categories"}}
  
  categories instproc render {} {

    my initialize -parameter {
      {-tree_name ""}
      {-tree_style:boolean 1}
      {-no_tree_name:boolean 0}
      {-count:boolean 0}
      {-summary:boolean 0}
      {-locale ""}
      {-open_page ""}
      {-category_ids ""}
      {-except_category_ids ""}
    }
    
    my get_parameters

    set content ""
    set folder_id [$package_id folder_id]
    set open_item_id [expr {$open_page ne "" ?
                            [CrItem lookup -name $open_page -parent_id $folder_id] : 0}]

    foreach {locale locale_clause} [my locale_clause $package_id $locale] break

    set have_locale [expr {[lsearch [info args category_tree::get_mapped_trees] locale] > -1}]
    set trees [expr {$have_locale ?
                     [category_tree::get_mapped_trees $package_id $locale] :
                     [category_tree::get_mapped_trees $package_id]}]
    foreach tree $trees {
      foreach {tree_id my_tree_name ...} $tree {break}
      if {$tree_name ne "" && ![string match $tree_name $my_tree_name]} continue
      if {!$no_tree_name} {
        append content "<h3>$my_tree_name</h3>"
      }
      set categories [list]
      set pos 0
      set cattree(0) [::xowiki::CatTree new -volatile -orderby pos -name $my_tree_name]
      set category_infos [expr {$have_locale ?
                                [category_tree::get_tree $tree_id $locale] :
                                [category_tree::get_tree $tree_id]}]

      foreach category_info $category_infos {
        foreach {cid category_label deprecated_p level} $category_info {break}
        
        set c [::xowiki::Category new -orderby pos -category_id $cid -package_id $package_id \
                   -level $level -label $category_label -pos [incr pos]]
        set cattree($level) $c
        set plevel [expr {$level -1}]
        $cattree($plevel) add $c
        set category($cid) $c
        lappend categories $cid
        #set itemobj [Object new -set name en:index -set title MyTitle -set prefix "" -set suffix ""]
        #$cattree(0) add_to_category -category $c -itemobj $itemobj -orderby title
      }
      
      set sql "category_object_map c, cr_items ci, cr_revisions r, xowiki_page p \
		where c.object_id = ci.item_id and ci.parent_id = $folder_id \
		and ci.content_type not in ('::xowiki::PageTemplate') \
		and category_id in ([join $categories ,]) \
		and r.revision_id = ci.live_revision \
		and p.page_id = r.revision_id"

      if {$except_category_ids ne ""} {
        append sql \
            " and not exists (select * from category_object_map c2 \
		where ci.item_id = c2.object_id \
		and c2.category_id in ($except_category_ids))"
      }
      #ns_log notice "--c category_ids=$category_ids"
      if {$category_ids ne ""} {
        foreach cid [split $category_ids ,] {
          append sql " and exists (select * from category_object_map \
	where object_id = ci.item_id and category_id = $cid)"
        }
      }
      append sql $locale_clause
      
      if {$count} {
        db_foreach get_counts \
            "select count(*) as nr,category_id from $sql group by category_id" {
              $category($category_id) set count $nr
              set s [expr {$summary ? "&summary=$summary" : ""}]
              $category($category_id) href [ad_conn url]?category_id=$category_id$s
              $category($category_id) open_tree
	  }
        append content [$cattree(0) render -tree_style $tree_style]
      } else {
        db_foreach get_pages \
            "select ci.item_id, ci.name, ci.content_type, r.title, category_id from $sql" {
              if {$title eq ""} {set title $name}
              set itemobj [Object new]
              set prefix ""
              set suffix ""
              foreach var {name title prefix suffix} {$itemobj set $var [set $var]}
              $cattree(0) add_to_category \
                  -category $category($category_id) \
                  -itemobj $itemobj \
                  -orderby title \
                  -open_item [expr {$item_id == $open_item_id}]
            }
        append content [$cattree(0) render -tree_style $tree_style]
      }
    }
    return $content
  }
}


namespace eval ::xowiki::portlet {
  #############################################################################
  # $Id$
  # display recent entries by categories
  # -gustaf neumann
  #
  # valid parameters from the include are 
  #     tree_name: match pattern, if specified displays only the trees with matching names
  #     max_entries: show given number of new entries
  
  Class create categories-recent \
      -superclass ::xowiki::Portlet \
      -parameter {{title "Recently Changed Pages by Categories"}}

  categories-recent instproc render {} {

    my initialize -parameter {
      {-max_entries:integer 10}
      {-tree_name ""}
      {-locale ""}
    }
    my get_parameters
  
    set cattree [::xowiki::CatTree new -volatile -name "categories-recent"]

    foreach {locale locale_clause} [my locale_clause $package_id $locale] break

    set have_locale [expr {[lsearch [info args category_tree::get_mapped_trees] locale] > -1}]
    set trees [expr {$have_locale ?
                     [category_tree::get_mapped_trees $package_id $locale] :
                     [category_tree::get_mapped_trees $package_id]}]

    foreach tree $trees {
      foreach {tree_id my_tree_name ...} $tree {break}
      if {$tree_name ne "" && ![string match $tree_name $my_tree_name]} continue
      lappend tree_ids $tree_id
    }
    if {[info exists tree_ids]} {
      set tree_select_clause "and c.tree_id in ([join $tree_ids ,])"
    } else {
      set tree_select_clause ""
    }
      
    db_foreach get_pages \
        "select c.category_id, ci.name, r.title, \
	 to_char(r.publish_date,'YYYY-MM-DD HH24:MI:SS') as publish_date \
       from category_object_map_tree c, cr_items ci, cr_revisions r, xowiki_page p \
       where c.object_id = ci.item_id and ci.parent_id = [$package_id folder_id] \
	 and r.revision_id = ci.live_revision \
	 and p.page_id = r.revision_id $tree_select_clause $locale_clause \
         and ci.publish_status <> 'production' \
	 order by r.publish_date desc limit $max_entries \
     " {
       if {$title eq ""} {set title $name}
       set itemobj [Object new]
       set prefix  "$publish_date "
       set suffix  ""
       foreach var {name title prefix suffix} {$itemobj set $var [set $var]}
       if {![info exists categories($category_id)]} {
	 set categories($category_id) [::xowiki::Category new \
                                           -package_id $package_id \
					   -label [category::get_name $category_id $locale]\
					   -level 1]
	 $cattree add  $categories($category_id)
       }
       $cattree add_to_category -category $categories($category_id) -itemobj $itemobj
     }
    return [$cattree render]
  }
}


namespace eval ::xowiki::portlet {
  #############################################################################
  #
  # display recent entries 
  #
  
  Class create recent \
      -superclass ::xowiki::Portlet \
      -parameter {{title "Recently Changed Pages"}}
  
  recent instproc render {} {
    ::xowiki::Page requireCSS "/resources/acs-templating/lists.css"

    my initialize -parameter {
      {-max_entries:integer 10}
    }
    my get_parameters
    
    TableWidget t1 -volatile \
        -columns {
          Field date -label "Modification Date"
          AnchorField title -label [_ xowiki.page_title]
        }
    
    db_foreach get_pages \
        "select i.name, r.title, \
                to_char(r.publish_date,'YYYY-MM-DD HH24:MI:SS') as publish_date \
         from cr_items i, cr_revisions r, xowiki_page p \
         where i.parent_id = [$package_id folder_id] \
                and r.revision_id = i.live_revision \
                and p.page_id = r.revision_id \
		and i.publish_status <> 'production' \
                order by r.publish_date desc limit $max_entries\
      " {
        t1 add \
            -title $title \
            -title.href [$package_id pretty_link $name] \
            -date $publish_date
      }
    return [t1 asHTML]
  }
}

namespace eval ::xowiki::portlet {
  #############################################################################
  # $Id$
  # display last visited entries 
  # -gustaf neumann
  #
  # valid parameters from the include are 
  #     max_entries: show given number of new entries
  #
  
  Class create last-visited \
      -superclass ::xowiki::Portlet \
      -parameter {{title "Last Visited Pages"}}
  
  last-visited instproc render {} {
    ::xowiki::Page requireCSS "/resources/acs-templating/lists.css"

    my initialize -parameter {
      {-max_entries:integer 20}
    }
    my get_parameters

    TableWidget t1 -volatile \
        -columns {
          AnchorField title -label [_ xowiki.page_title]
        }

    db_foreach get_pages \
        "select r.title,i.name, to_char(x.time,'YYYY-MM-DD HH24:MI:SS') as visited_date  \
           from xowiki_last_visited x, xowiki_page p, cr_items i, cr_revisions r  \
           where x.page_id = i.item_id and i.live_revision = p.page_id  \
	    and r.revision_id = p.page_id and x.user_id = [::xo::cc user_id] \
	    and x.package_id = $package_id  and i.publish_status <> 'production' \
	order by x.time desc limit $max_entries \
      " {
        t1 add \
            -title $title \
            -title.href [$package_id pretty_link $name] 
      }
    return [t1 asHTML]
  }
}


namespace eval ::xowiki::portlet {
  #############################################################################
  #
  # list the most popular pages
  #

  Class create most-popular \
      -superclass ::xowiki::Portlet \
      -parameter {{title "Most Popular Pages"}}
  
  most-popular instproc render {} {
    ::xowiki::Page requireCSS "/resources/acs-templating/lists.css"

    my initialize -parameter {
      {-max_entries:integer "10"}
    }
    my get_parameters
   
    TableWidget t1 -volatile \
        -columns {
          AnchorField title -label [_ xowiki.page_title]
          Field count -label Count -html { align right }
        }

    db_foreach get_pages \
        "select sum(x.count), x.page_id, r.title,i.name  \
          from xowiki_last_visited x, xowiki_page p, cr_items i, cr_revisions r  \
          where x.page_id = i.item_id and i.live_revision = p.page_id  and r.revision_id = p.page_id \
            and x.package_id = $package_id and i.publish_status <> 'production' \
            group by x.page_id, r.title, i.name \
            order by sum desc limit $max_entries " \
        {
          t1 add \
              -title $title \
              -title.href [$package_id pretty_link $name] \
              -count $sum
        }
    return [t1 asHTML]
  }
}

namespace eval ::xowiki::portlet {
  #############################################################################
  #
  # Show the tags
  #

  Class create tags \
      -superclass ::xowiki::Portlet \
      -parameter {{title "Tags"}}
  
  tags instproc render {} {
    ::xowiki::Page requireCSS "/resources/acs-templating/lists.css"

    my initialize -parameter {
      {-limit:integer 20}
      {-summary:boolean 0}
      {-popular:boolean 0}
    }
    my get_parameters
    
    if {$popular} {
      set label [_ xowiki.popular_tags_label]
      set tag_type ptag
      set sql "select count(*) as nr,tag from xowiki_tags where \
        package_id=$package_id group by tag order by tag limit $limit"
    } else {
      set label [_ xowiki.your_tags_label]
      set tag_type tag 
      set sql "select count(*) as nr,tag from xowiki_tags where \
        user_id=[::xo::cc user_id] and package_id=$package_id group by tag order by tag"
    }
    set content "<h3>$label</h3> <BLOCKQUOTE>"
    set entries [list]
    db_foreach get_counts $sql {
      set s [expr {$summary ? "&summary=$summary" : ""}]
      set href [ad_conn url]?$tag_type=[ad_urlencode $tag]$s
      lappend entries "$tag <a href='$href'>($nr)</a>"
    }
    append content "[join $entries {, }]</BLOCKQUOTE>\n"
    return $content
  }

}

namespace eval ::xowiki::portlet {
  #############################################################################
  # presence
  #
  Class create presence \
      -superclass ::xowiki::Portlet \
      -parameter {{__decoration plain}}

  # TODO make display style -decoration

  presence instproc render {} {
    my initialize -parameter {
      {-interval "10 minutes"}
      {-max_users:integer 40}
      {-show_anonymous "summary"}
      {-page}
    }
    my get_parameters

    set summary 0
    if {[::xo::cc user_id] == 0} {
      switch -- $show_anonymous {
        nothing {return ""}
        all {set summary 0} 
        default {set summary 1} 
      }
    }

    if {$summary} {
      set select_count "select count(distinct user_id) from xowiki_last_visited "
      set order_clause ""
    } else {
      set select_users "select distinct user_id,time from xowiki_last_visited "
      set limit_clause "limit $max_users"
      set order_clause "order by time desc $limit_clause"
    }
    set where_clause "\
        where package_id = $package_id \
        and time > now() - '$interval'::interval "
    set when "<br>in last $interval"

    if {[info exists page] && $page eq "this"} {
      my instvar __including_page
      append where_clause "and page_id = [$__including_page item_id] "
      set what " on page [$__including_page title]"
    } else {
      set what " in community [$package_id instance_name]"
    }

    set output ""

    if {$summary} {
      set count [db_string presence_count_users "$select_count $where_clause"] 
    } else {
      set values [db_list_of_lists get_users "$select_users $where_clause $order_clause"]
      set count [llength $values]
      if {$count == $max_users} {
        # we have to check, whether there were more users...
        set count [db_string presence_count_users "$select_count $where_clause"] 
      }
      foreach value  $values {
        foreach {user_id time} $value break
        set seen($user_id) $time
        
        regexp {^([^.]+)[.]} $time _ time
        set pretty_time [util::age_pretty -timestamp_ansi $time \
                             -sysdate_ansi [clock_to_ansi [clock seconds]] \
                             -mode_3_fmt "%d %b %Y, at %X"]
        
        set name [::xo::get_user_name $user_id]
        append output "<TR><TD class='user'>$name</TD><TD class='timestamp'>$pretty_time</TD></TR>\n"
      }
      if {$output ne ""} {set output "<TABLE>$output</TABLE>\n"}
    }
    set users [expr {$count == 0 ? "No users" : 
                     $count == 1 ? "1 registered user" : 
                     "$count registered users"}]
    return "<H1>$users$what$when</H1>$output"
  }
}


namespace eval ::xowiki::portlet {
  #############################################################################
  # portlets based on order
  #
  Class create toc \
      -superclass ::xowiki::Portlet \
      -parameter {{__decoration plain}}

#"select page_id,  page_order, name, title, \
#	(select count(*)-1 from xowiki_page_live_revision where page_order <@ p.page_order) as count \
#	from xowiki_page_live_revision p where not page_order is NULL order by page_order asc"

  toc instproc count {} {return [my set navigation(count)]}
  toc instproc current {} {return [my set navigation(current)]}
  toc instproc position {} {return [my set navigation(position)]}
  toc instproc page_name {p} {return [my set page_name($p)]}

  toc instproc get_nodes {open_page package_id expand_all remove_levels} {
    my instvar navigation page_name book_mode
    array set navigation {parent "" position 0 current ""}

    set js ""
    set node() root
    set node_cnt 0

    set folder_id [$package_id set folder_id]
    set pages [::xowiki::Page instantiate_objects -sql "select page_id,  page_order, name, title \
	from xowiki_page_live_revision p \
	where parent_id = $folder_id \
	and not page_order is NULL"]
    $pages mixin add ::xo::OrderedComposite::IndexCompare
    $pages orderby page_order

    my set jsobjs ""

    foreach o [$pages children] {
      $o instvar page_order title page_id name title 

      #my log "o: $page_order"
      set displayed_page_order $page_order
      for {set i 0} {$i < $remove_levels} {incr i} {
	regsub {^[^.]+[.]} $displayed_page_order "" displayed_page_order
      }
      set label "$displayed_page_order $title"
      set id tmpNode[incr node_cnt]
      set node($page_order) $id
      set jsobj TocTree.objs\[$node_cnt\]

      set page_name($node_cnt) $name
      if {![regexp {^(.*)[.]([^.]+)} $page_order _ parent]} {set parent ""}

      if {$book_mode} {
	regexp {^.*:([^:]+)$} $name _ anchor
	set href [$package_id url]#$anchor
      } else {
	set href [$package_id pretty_link $name]
      }
      
      if {$expand_all} {
	set expand "true"
      } else {
	set expand [expr {$open_page eq $name} ? "true" : "false"]
	if {$expand} {
	  set navigation(parent) $parent
	  set navigation(position) $node_cnt
	  set navigation(current) $page_order
	  for {set p $parent} {$p ne ""} {} {
	    if {![info exists node($p)]} break
	    append js "$node($p).expand();\n"
	    if {![regexp {^(.*)[.]([^.]+)} $p _ p]} {set p ""}
	  }
	}
      }
      set parent_node [expr {[info exists node($parent)] ? $node($parent) : "root"}]
      set refvar [expr {[my set ajax] ? "ref" : "href"}]
      append js \
	  "$jsobj = {label: \"$label\", id: \"$id\", $refvar: \"$href\",  c: $node_cnt};" \
	  "var $node($page_order) = new YAHOO.widget.TextNode($jsobj, $parent_node, $expand);\n" \
          ""
      my lappend jsobjs $jsobj

    }
    set navigation(count) $node_cnt
    #my log "--COUNT=$node_cnt"
    return $js
  }

  toc instproc ajax_tree {js_tree_cmds} {
    return "<div id='[self]'>
      <script type = 'text/javascript'>
      var TocTree = {

         count : this.count = [my set navigation(count)],

         getPage: function(href, c) {
             //  console.log('getPage: ' + href + ' type: ' + typeof href) ;

             if ( typeof c == 'undefined' ) {

                 // no c given, search it from the objects
                 // console.log('search for href <' + href + '>');

                 for (i in this.objs) {
                     if (this.objs\[i\].ref == href) {
                        c = this.objs\[i\].c;
                        // console.log('found href ' + href + ' c=' + c);
                        var node = this.tree.getNodeByIndex(c);
                        if (!node.expanded) {node.expand();}
                        node = node.parent;
                        while (node.index > 1) {
                            if (!node.expanded) {node.expand();}
                            node = node.parent;
                        }
                        break;
                     }
                 }
                 if (typeof c == 'undefined') {
                     // console.warn('c undefined');
                     return false;
                 }
             }
             // console.log('have href ' + href + ' c=' + c);

             var transaction = YAHOO.util.Connect.asyncRequest('GET', \
                 href + '?template_file=view-page', 
                {
                  success:function(o) {
                     var bookpage = document.getElementById('book-page');
     		     var fadeOutAnim = new YAHOO.util.Anim(bookpage, { opacity: {to: 0} }, 0.5 );

                     var doFadeIn = function(type, args) {
                        // console.log('fadein starts');
                        var bookpage = document.getElementById('book-page');
                        bookpage.innerHTML = o.responseText;
                        var fadeInAnim = new YAHOO.util.Anim(bookpage, { opacity: {to: 1} }, 0.1 );
                        fadeInAnim.animate();
                     }

                     // console.log(' tree: ' + this.tree + ' count: ' + this.count);
                     // console.info(this);

                     if (this.count > 0) {
                        var percent = (100 * o.argument / this.count).toFixed(2) + '%';
                     } else {
                        var percent = '0.00%';
                     }

                     if (o.argument > 1) {
                        var link = this.objs\[o.argument - 1 \].ref;
                        var src = '/resources/xowiki/previous.png';
                        var onclick = 'return TocTree.getPage(\"' + link + '\");' ;
                     } else {
                        var link = '#';
                        var onclick = '';
                        var src = '/resources/xowiki/previous-end.png';
                     }

                     // console.log('changing prev href to ' + link);
                     // console.log('changing prev onclick to ' + onclick);

                     document.getElementById('bookNavPrev.img').src = src;
                     document.getElementById('bookNavPrev.a').href = link;
                     document.getElementById('bookNavPrev.a').setAttribute('onclick',onclick);

                     if (o.argument < this.count) {
                        var link = this.objs\[o.argument + 1 \].ref;
                        var src = '/resources/xowiki/next.png';
                        var onclick = 'return TocTree.getPage(\"' + link + '\");' ;
                     } else {
                        var link = '#';
                        var onclick = '';
                        var src = '/resources/xowiki/next-end.png';
                     }

                     // console.log('changing next href to ' + link);
                     // console.log('changing next onclick to ' + onclick);
                     document.getElementById('bookNavNext.img').src = src;
                     document.getElementById('bookNavNext.a').href = link;

                     document.getElementById('bookNavNext.a').setAttribute('onclick',onclick);
                     document.getElementById('bookNavRelPosText').innerHTML = percent;
                     document.getElementById('bookNavBar').setAttribute('style', 'width: ' + percent + ';');

                     fadeOutAnim.onComplete.subscribe(doFadeIn);
  		     fadeOutAnim.animate();
                  }, 
                  failure:function(o) {
                     // console.error(o);
                     // alert('failure ');
                     return false;
                  },
                  argument: c,
                  scope: TocTree
                }, null);

                return false;
            },


         treeInit: function() { 
            TocTree.tree = new YAHOO.widget.TreeView('[self]'); 
            root = TocTree.tree.getRoot(); 
            TocTree.objs = new Array();
            $js_tree_cmds

            TocTree.tree.subscribe('labelClick', function(node) {
              TocTree.getPage(node.data.ref, node.data.c); });
            TocTree.tree.draw();
         }

      };

     YAHOO.util.Event.addListener(window, 'load', TocTree.treeInit);
      </script>
    </div>"
  }

  toc instproc tree {js_tree_cmds} {
    return "<div id='[self]'>
      <script type = 'text/javascript'>
      var TocTree = {

         getPage: function(href, c) { return true; },

         treeInit: function() { 
            TocTree.tree = new YAHOO.widget.TreeView('[self]'); 
            root = TocTree.tree.getRoot(); 
            TocTree.objs = new Array();
            $js_tree_cmds
            TocTree.tree.draw();
         }
      };
      YAHOO.util.Event.on(window, 'load', TocTree.treeInit);
      </script>
    </div>"
  }


  toc instproc render {} {
    my initialize -parameter {
      {-style ""} 
      {-open_page ""}
      {-book_mode false}
      {-ajax true}
      {-expand_all false}
      {-remove_levels 0}
    }
    my get_parameters
    switch -- $style {
      "menu" {set s "menu/"}
      "folders" {set s "folders/"}
      "default" {set s ""}
    }
    ::xowiki::Page requireCSS "/resources/ajaxhelper/yui/treeview/assets/${s}tree.css"
    ::xowiki::Page requireJS "/resources/ajaxhelper/yui/yahoo/yahoo.js"
    ::xowiki::Page requireJS "/resources/ajaxhelper/yui/event/event.js"
    if {$ajax} {
       ::xowiki::Page requireJS "/resources/ajaxhelper/yui/dom/dom.js"             ;# ANIM
       ::xowiki::Page requireJS "/resources/ajaxhelper/yui/connection/connection.js"
       ::xowiki::Page requireJS "/resources/ajaxhelper/yui/animation/animation.js" ;# ANIM
    }  
    ::xowiki::Page requireJS "/resources/ajaxhelper/yui/treeview/treeview.js"
    #::xowiki::Page requireJS "http://www.json.org/json.js"   ;# for toJSONString


    my set book_mode $book_mode
    if {!$book_mode} {
      ###### my set book_mode [[my set __including_page] exists __is_book_page]
    } elseif $ajax {
      #my log "--warn: cannot use bookmode with ajax, resetting ajax"
      set ajax 0
    }
    my set ajax $ajax
            
    set js_tree_cmds [my get_nodes $open_page $package_id $expand_all $remove_levels]

    return [expr {$ajax ? [my ajax_tree $js_tree_cmds ] : [my tree $js_tree_cmds ]}]
  }

  #############################################################################
  # book style
  #
  Class create book \
      -superclass ::xowiki::Portlet \
      -parameter {{__decoration plain}}

  book instproc render {} {
    my initialize -parameter { }
    my get_parameters

    my instvar __including_page
    lappend ::xowiki_page_item_id_rendered [$__including_page item_id]
    $__including_page set __is_book_page 1

    set pages [::xowiki::Page instantiate_objects -sql \
        "select page_id, page_order, name, title, item_id \
		from xowiki_page_live_revision p \
		where parent_id = [$package_id folder_id] \
		and not page_order is NULL \
		[::xowiki::Page container_already_rendered item_id]" ]
    $pages mixin add ::xo::OrderedComposite::IndexCompare
    $pages orderby page_order

    set output ""
    set return_url [::xo::cc url]

    foreach o [$pages children] {
      $o instvar page_order title page_id name title 
      set level [expr {[regsub {[.]} $page_order . page_order] + 1}]
      set p [::Generic::CrItem instantiate -item_id 0 -revision_id $page_id]
      $p destroy_on_cleanup
      set p_link [$package_id pretty_link $name]
      set edit_link [$p make_link -url $p_link $p edit return_url]
      if {$edit_link ne ""} {
        set edit_markup "<div style='float: right'><a href=\"$edit_link\"><image src='/resources/acs-subsite/Edit16.gif' border='0' ></a></div>"
      } else {
        set edit_markup ""
      }
      
      $p set unresolved_references 0
      #$p set render_adp 0
      set content [$p get_content]
      if {[regexp package_id $content]} {my log "--CONTENT 0 $content"}
      set content [string map [list "\{\{" "\\\{\{"] $content]
     if {[regexp package_id $content]} {my log "--CONTENT 1 $content"}
      regexp {^.*:([^:]+)$} $name _ anchor
      append output "<h$level class='book'>" \
          $edit_markup \
          "<a name='$anchor'>$page_order $title</h$level>" \
          $content
    }
    return $output
  }
}

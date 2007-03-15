ad_library {
    XoWiki - adp generator procs: remove redundancy in adp files by generating it

    @creation-date 2007-03-13
    @author Gustaf Neumann
    @cvs-id $Id$
}


namespace eval ::xowiki {
  
  Class ADP_Generator -parameter {
    {master 1} 
    {wikicmds 1} 
    {footer 1} 
    {recreate 0}
    {extra_header_stuff ""}
  }

  ADP_Generator instproc before_render {} {
    # just a hook, might be removed later
  }

  ADP_Generator instproc ajax_tag_definition {} {
    # if we have no footer, we have no tag form
    if {![my footer]} {return ""}

    return {<script type="text/javascript">
function get_popular_tags(popular_tags_link, prefix) {
  var http = getHttpObject();
  http.open('GET', popular_tags_link, true);
  http.onreadystatechange = function() {
    if (http.readyState == 4) {
      if (http.status != 200) {
	alert('Something wrong in HTTP request, status code = ' + http.status);
      } else {
       var e = document.getElementById(prefix + '-popular_tags');
       e.innerHTML = http.responseText;
       e.style.display = 'block';
      }
    }
  };
  http.send(null);
}
</script>}
  }

  ADP_Generator instproc master_part {} {
    return [subst -novariables -nobackslashes \
{<master>
  <property name="title">@title;noquote@</property>
  <property name="context">@context;noquote@</property>
  <property name="header_stuff">@header_stuff;noquote@[my extra_header_stuff]
  <link rel="stylesheet" type="text/css" href="/resources/xowiki/xowiki.css" media="all" />
  [my ajax_tag_definition]
  </property>}]\n
  }

  ADP_Generator instproc wikicmds_part {} {
    if {![my wikicmds]} {return ""}
    return {<div id='wikicmds'>
  <if @edit_link@ not nil><a href="@edit_link@" accesskey='e' title='Diese Seite bearbeiten ...'>#xowiki.edit#</a> &middot; </if>
  <if @rev_link@ not nil><a href="@rev_link@" accesskey='r' >#xotcl-core.revisions#</a> &middot; </if>
  <if @new_link@ not nil><a href="@new_link@" accesskey='n'>#xowiki.new#</a> &middot; </if>
  <if @delete_link@ not nil><a href="@delete_link@" accesskey='d'>#xowiki.delete#</a> &middot; </if>
  <if @admin_link@ not nil><a href="@admin_link@" accesskey='a'>#xowiki.admin#</a> &middot; </if>
  <if @notification_subscribe_link@ not nil><a href='/notifications/manage'>#xowiki.notifications#</a> 
    <a href="@notification_subscribe_link@">@notification_image;noquote@</a> &middot; </if>
  <a href='#' onclick='document.getElementById("do_search").style.display="inline";document.getElementById("do_search_q").focus(); return false;'>#xowiki.search#</a> &middot;
  <if @index_link@ not nil><a href="@index_link@" accesskey='i'>#xowiki.index#</a></if>
<span id='do_search' style='display: none'> 
  <FORM action='/search/search'><INPUT  id='do_search_q' name='q' type='text'><INPUT type="hidden" name="search_package_id" value="@package_id@" /></FORM> 
</span>
</div>}
  }

  ADP_Generator instproc footer_part {} {
    if {![my footer]} {return ""}
    return {<div style="clear: both; text-align: left; font-size: 85%;">
<hr/>
<if @digg_link@ not nil>
<div style='float: right'><a href='@digg_link@'><img  src='http://digg.com/img/badges/100x20-digg-button.png' width='100' height='20' alt='Digg!' border='1'/></a></div>
</if>
<if @delicious_link@ not nil>
<div style='float: right; padding-right: 10px;'><a href='@delicious_link@'><img src="http://i.i.com.com/cnwk.1d/i/ne05/fmwk/delicious_14x14.gif" width="14" height="14" border="0" alt="Add to your del.icio.us" />del.icio.us</a></div>
</if>
<if @my_yahoo_link@ not nil>
<div style='float: right; padding-right: 10px;'>
<a href="@my_yahoo_link@"><img src="http://us.i1.yimg.com/us.yimg.com/i/us/my/addtomyyahoo4.gif" width="91" height="17" border="0" align="middle" alt="Add to My Yahoo!"></a></div>
</if>
<if @references@ ne "" or @lang_links.found@ ne "">
#xowiki.references_label# @references;noquote@ @lang_links.found;noquote@<br/>
</if>
<if @lang_links.undefined@ ne "">
#xowiki.create_this_page_in_language# @lang_links.undefined;noquote@<br/>
</if>
<if @no_tags@ eq 0>
#xowiki.your_tags_label#: @tags_with_links;noquote@
(<a href='#' onclick='document.getElementById("-edit_tags").style.display="inline";return false;'>#xowiki.edit_link#</a>, 
<a href='#' onclick='get_popular_tags("@popular_tags_link@","");return false;'>#xowiki.popular_tags_link#</a>)
<span id='-edit_tags' style='display: none'>
<FORM action="@save_tag_link@" method='POST'><INPUT name='new_tags' type='text' value="@tags@"></FORM>
</span>
<span id='-popular_tags' style='display: none'></span><br/>
</if>
<if @per_object_categories_with_links@ not nil and @per_object_categories_with_links@ ne "">
Categories: @per_object_categories_with_links;noquote@
</if>
</div>
<if @gc_comments@ not nil>
   <p>#general-comments.Comments#
   <ul>@gc_comments;noquote@</ul></p>
</if>
<if @gc_link@ not nil>
   <p>@gc_link;noquote@</p>
</if>}
  }

  ADP_Generator instproc content_part {} {
    return "@top_portlets;noquote@\n@content;noquote@"
  }


  ADP_Generator instproc generate {} {
    my instvar master wikicmds footer
    set _ "<!-- Generated by [self class] on [clock format [clock seconds]] -->\n"

    # if we include the master, we include the primitive js function
    if {$master} {
      append _ [my master_part]
    }

    append _ \
{<!-- The following DIV is needed for overlib to function! -->
  <div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>	
<div class='xowiki-content'>} \n

    append _ [my wikicmds_part] \n
    append _ [my content_part] \n
    append _ [my footer_part] \n
    append _ "</div> <!-- class='xowiki-content' -->\n"
  }

  ADP_Generator instproc init {} {
    set name [namespace tail [self]]
    set filename [file dirname [info script]]/../www/$name.adp
    # generate the adp file, if it does not exist
    if {![file exists $filename]} {
      set f [open $filename w]
      puts -nonewline $f [my generate]
      close $f
    }
  }

  ADP_Generator create view-plain -master 0 -wikicmds 0 -footer 0
  ADP_Generator create view-links -master 0 -footer 0
  ADP_Generator create view-default -master 1 -footer 1

  ADP_Generator create oacs-view -master 1 -footer 1 \
    -extra_header_stuff {
      <link rel='stylesheet' href='/resources/xowiki/cattree.css' media='all' />
      <script language='javascript' src='/resources/acs-templating/mktree.js' type='text/javascript'></script>
    } \
    -proc content_part {} {
       return [subst -novariables -nobackslashes \
{<div style="float:left; width: 25%; font-size: 85%;
     background: url(/resources/xowiki/bw-shadow.png) no-repeat bottom right;
     margin-left: 2px; margin-top: 2px; padding: 0px 6px 6px 0px;			    
">
<div style="margin-top: -2px; margin-left: -2px; border: 1px solid #a9a9a9; padding: 5px 5px; background: #f8f8f8">
<include src="/packages/xowiki/www/portlets/include" 
	 &__including_page=page 
	 portlet="categories -open_page @name@  -decoration plain">
</div></div>
<div style="float:right; width: 70%;">
[next]
</div>
}]
     }

  #
  # similar to oacs view (categories left), but having as well a right bar
  #
  ADP_Generator create oacs-view2 -master 1 -footer 1 \
    -extra_header_stuff {
      <link rel='stylesheet' href='/resources/xowiki/cattree.css' media='all' />
      <link rel='stylesheet' href='/resources/calendar/calendar.css' media='all' />
      <script language='javascript' src='/resources/acs-templating/mktree.js' type='text/javascript'></script>
    } \
    -proc before_render {} {
      ::xo::cc set_parameter weblog_page weblog-portlet
    } \
    -proc content_part {} {
       return [subst -novariables -nobackslashes \
{<div style="float:left; width: 25%; font-size: 85%;
     background: url(/resources/xowiki/bw-shadow.png) no-repeat bottom right;
     margin-left: 2px; margin-top: 2px; padding: 0px 6px 6px 0px;			    
">
<div style="margin-top: -2px; margin-left: -2px; border: 1px solid #a9a9a9; padding: 5px 5px; background: #f8f8f8">
<include src="/packages/xowiki/www/portlets/include" 
	 &__including_page=page 
	 portlet="categories -open_page @name@  -decoration plain">
</div></div>
<div style="float:right; width: 70%;">
<style type='text/css'>
table.mini-calendar {width: 200px ! important;}
#sidebar {min-width: 220px ! important; top: 0px; overflow: visible;}
</style>
<div style='float: left; width: 62%'>
[next]
</div>  <!-- float left -->
<div id='sidebar' class='column'>
<div style="background: url(/resources/xowiki/bw-shadow.png) no-repeat bottom right;
     margin-left: 2px; margin-top: 2px; padding: 0px 6px 6px 0px;			    
">
<div style="margin-top: -2px; margin-left: -2px; border: 1px solid #a9a9a9; padding: 5px 5px; background: #f8f8f8">
<include src="/packages/xowiki/www/portlets/weblog-mini-calendar" 
	 &__including_page=page 
         summary="1" noparens="1">
<include src="/packages/xowiki/www/portlets/include" 
	 &__including_page=page 
	 portlet="tags -decoration plain -summary 1">
<include src="/packages/xowiki/www/portlets/include" 
	 &__including_page=page 
	 portlet="tags -popular 1 -limit 30 -decoration plain -summary 1">
<hr>
<include src="/packages/xowiki/www/portlets/include" 
	 &__including_page=page 
	 portlet="presence -interval {30 minutes} -decoration plain">
</div>
</div>
</div> <!-- sidebar -->

</div> <!-- right 70% -->
}]
     }


}

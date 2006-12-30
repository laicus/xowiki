<master>
  <property name="title">@title;noquote@</property>
  <property name="context">@context;noquote@</property>
  <property name="header_stuff">@header_stuff;noquote@
<link rel='stylesheet' href='/resources/xowiki/cattree.css' media='all'>
<script language='javascript' src='/resources/acs-templating/mktree.js' type='text/javascript'></script>
<link rel="stylesheet" type="text/css" href="/resources/xowiki/xowiki.css" media="all" />
<script type="text/javascript">
function get_popular_tags() {
  var http = getHttpObject();
  http.open('GET', "@popular_tags_link@", true);
  http.onreadystatechange = function() {
    if (http.readyState == 4) {
      if (http.status != 200) {
	alert('Something wrong in HTTP request, status code = ' + http.status);
      } else {
       var e = document.getElementById('popular_tags');
       e.innerHTML = http.responseText;
       e.style.display = 'block';
      }
    }
  };
  http.send(null);
}
</script>
</property>
  
  <!-- The following DIV is needed for overlib to function! -->
  <div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>	

<div id='wikicmds'>
  <if @edit_link@ not nil><a href="@edit_link@" accesskey='e' title='Diese Seite bearbeiten ...'>#xowiki.edit#</a> &middot; </if>
  <if @rev_link@ not nil><a href="@rev_link@" accesskey='r' >#xotcl-core.revisions#</a> &middot;</if>
  <if @new_link@ not nil><a href="@new_link@" accesskey='n'>#xowiki.new#</a> &middot;</if>
  <if @delete_link@ not nil><a href="@delete_link@" accesskey='d'>#xowiki.delete#</a> &middot;</if>
  <if @admin_link@ not nil><a href="@admin_link@" accesskey='a'>#xowiki.admin#</a> &middot;</if>
  <if @notification_subscribe_link@ not nil><a href='/notifications/manage'>#xowiki.notifications#</a> 
    <a href="@notification_subscribe_link@">@notification_image;noquote@</a> &middot;</if>
  <a href='#' onclick='document.getElementById("do_search").style.display="inline";document.getElementById("do_search_q").focus(); return false;'>#xowiki.search#</a> &middot;
  <if @index_link@ not nil><a href="@index_link@" accesskey='i'>#xowiki.index#</a></if>
<span id='do_search' style='display: none'> 
  <FORM action='/search/search'><INPUT  id='do_search_q' name='q' type='text'><INPUT type="hidden" name="search_package_id" value="@package_id@" /></FORM> 
</span>
</div>

<div style="float:left; width: 25%; font-size: .8em;
     background: url(/resources/xowiki/bw-shadow.png) no-repeat bottom right;
     margin-left: 2px; margin-top: 2px; padding: 0px 6px 6px 0px;			    
">
<div style="margin-top: -2px; margin-left: -2px; border: 1px solid #a9a9a9; padding: 5px 5px; background: #f8f8f8">
@toc;noquote@
</div></div>
<div style="float:right; width: 70%;">@top_portlets;noquote@

<if @book_prev_link@ not nil or @book_relpos@ not nil or @book_next_link@ not nil>
<div class="book-navigation" style="background: #f8f8f8; border: 1px solid #a9a9a9;  width: 500px;">
<table width='100%'>
   <tr>
   <td width='20'>
   <if @book_prev_link@ not nil>
        <a href="@book_prev_link@" accesskey='p'>
        <img border='0' alt='Previous' src='/resources/xowiki/previous.png' width='15px'></a>
    </if>
    <else><img border='0' alt='No Previous' src='/resources/xowiki/previous-end.png' width='15px'></else>
     </td>

   <td>
   <if @book_relpos@ not nil>
     <table style='display: inline; text-align: center;'>
     <tr><td width='450px' style='font-size: 75%'><div style='top: 0px; height: 2px; background-color: #859db8; width: @book_relpos@;'></div>@book_relpos@</td></tr>
     </table>
   </if>
   </td>

   <td width='20'>
   <if @book_next_link@ not nil>
        <a href="@book_next_link@" accesskey='n'>
        <img border='0' alt='Next' src='/resources/xowiki/next.png' width='15px'></a>
   </if>
    <else><img border='0' alt='No Next' src='/resources/xowiki/next-end.png' width='15px'></else>
   </td>
   </tr>
</table>
</div>
<if @page_title@ not nil>
@page_title;noquote@
</if>
</if>

@content;noquote@

</div>
<div style="clear: both; text-align: left; font-size: 85%;">
<hr>
<if @digg_link@ not nil>
<div style='float: right'><a href='@digg_link@'><img  src='http://digg.com/img/badges/100x20-digg-button.png' width='100' height='20' alt='Digg!' border='1'/></a></div>
</if>
<if @delicious_link@ not nil>
<div style='float: right; padding-right: 10px;'><a href='@delicious_link@'><img src="http://i.i.com.com/cnwk.1d/i/ne05/fmwk/delicious_14x14.gif" width="14" height="14" border="0" alt="Add to your del.icio.us" />del.icio.us</a></div>
</if>
<div style="clear: both; text-align: left; font-size: 85%;">
<if @references@ ne "" or @lang_links@ ne "">
#xowiki.references_label# @references;noquote@ @lang_links;noquote@
</if>
<br>
<if @no_tags@ eq 0>
#xowiki.your_tags_label#: @tags_with_links;noquote@
(<a href='#' onclick='document.getElementById("edit_tags").style.display="inline";return false;'>#xowiki.edit_link#</a>, 
<a href='#' onclick='get_popular_tags();return false;'>#xowiki.popular_tags_link#</a>)
<span id='edit_tags' style='display: none'>
<FORM action="@save_tag_link@" method='POST'><INPUT name='new_tags' type='text' value="@tags@"></FORM>
</span>
<span id='popular_tags' style='display: none'></span><br>
</if>
<if @per_object_categories_with_links@ not nil and @per_object_categories_with_links@ ne "">
Categories: @per_object_categories_with_links;noquote@
</if>
</div><br>
<if @gc_comments@ not nil>
   <p>#general-comments.Comments#
   <ul>@gc_comments;noquote@</ul></p>
</if>
<if @gc_link@ not nil>
   <p>@gc_link;noquote@</p>
</if>

<!-- Generated by ::xowiki::ADP_Generator on Do Mär 12 13:42:25 CET 2009 -->
<master>
  <property name="title">@title;noquote@</property>
  <property name="context">@context;noquote@</property>
  <property name="&body">property_body</property>
  <property name="&doc">property_doc</property>
  <property name="header_stuff">
  <link rel="stylesheet" type="text/css" href="/resources/xowiki/xowiki.css" media="all" >
  
    @header_stuff;noquote@
  <script type="text/javascript">
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
</script>
  </property>
  <property name="head">
  <link rel="stylesheet" type="text/css" href="/resources/xowiki/xowiki.css" media="all" >
  
    @header_stuff;noquote@
  <script type="text/javascript">
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
</script>
  </property>
<!-- The following DIV is needed for overlib to function! -->
  <div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>	
<div class='xowiki-content'>

<div style="float:left; width: 25%; font-size: .8em;
     background: url(/resources/xowiki/bw-shadow.png) no-repeat bottom right;
     margin-left: 2px; margin-top: 2px; padding: 0px 6px 6px 0px;			    
">
<div style="margin-top: -2px; margin-left: -2px; border: 1px solid #a9a9a9; padding: 5px 5px; background: #f8f8f8">
@toc;noquote@
</div></div>
<div style="float:right; width: 70%;">@top_includelets;noquote@

<if @book_prev_link@ not nil or @book_relpos@ not nil or @book_next_link@ not nil>
<div class="book-navigation" style="background: #f8f8f8; border: 1px solid #a9a9a9;  width: 500px;">
<table width='100%' 
  summary='This table provides a progress bar and buttons for next and previous pages'>
  <colgroup><col width='20'><col width='450'><col width='20'>
  </colgroup>
   <tr>
   <td>
   <if @book_prev_link@ not nil>
        <a href="@book_prev_link@" accesskey='p' ID="bookNavPrev.a" onclick='return TocTree.getPage("@book_prev_link@");'>
  <img alt='Previous' src='/resources/xowiki/previous.png' width='15' ID="bookNavPrev.img"></a>
    </if>
    <else>
        <a href="" accesskey='p' ID="bookNavPrev.a" onclick="">
        <img alt='No Previous' src='/resources/xowiki/previous-end.png' width='15' ID="bookNavPrev.img"></a>
    </else>
     </td>

   <td>
   <if @book_relpos@ not nil>
     <table style='display: inline; text-align: center;'>
     <colgroup><col width='450'></colgroup>
     <tr><td style='font-size: 75%'><div style='width: @book_relpos@;' ID='bookNavBar'></div><span ID='bookNavRelPosText'>@book_relpos@</span></td></tr>
     </table>
   </if>
   </td>

   <td ID="bookNavNext">
   <if @book_next_link@ not nil>
        <a href="@book_next_link@" accesskey='n' ID="bookNavNext.a" onclick='return TocTree.getPage("@book_next_link@");'>
        <img alt='Next' src='/resources/xowiki/next.png' width='15' ID="bookNavNext.img"></a>
   </if>
    <else>
        <a href="" accesskey='n' ID="bookNavNext.a" onclick="">
       <img alt='No Next' src='/resources/xowiki/next-end.png' width='15' ID="bookNavNext.img"></a>
    </else>
   </td>
   </tr>
</table>
</div>
</if>

<div id='book-page'>
<include src="view-page" &="package_id"
      &="references" &="name" &="title" &="item_id" &="page" &="context" &="header_stuff" &="return_url" 
      &="content" &="references" &="lang_links" &="package_id" 
      &="rev_link" &="edit_link" &="delete_link" &="new_link" &="admin_link" &="index_link" 
      &="tags" &="no_tags" &="tags_with_links" &="save_tag_link" &="popular_tags_link" 
      &="per_object_categories_with_links" 
      &="digg_link" &="delicious_link" &="my_yahoo_link" 
      &="gc_link" &="gc_comments" &="notification_subscribe_link" &="notification_image" 
      &="top_includelets" &="page">
</div>
</div>

@footer;noquote@
</div> <!-- class='xowiki-content' -->

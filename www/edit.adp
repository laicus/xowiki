<master>
  <property name="title">@page_title;noquote@</property>
  <property name="context">@context;noquote@</property>
  <property name="focus">note.title</property>

<style type='text/css'>
#wikicmds {position: relative;top: -50px;  right: 0px; height: 0px;
	  text-align: right;  font-family: sans-serif; font-size: 85%;color: #7A7A78;}
#wikicmds a, #wikicmds a:visited { color: #7A7A78; text-decoration: none;}
#wikicmds a:hover {text-decoration: underline;}
#wikicmds a:active {color: rgb(255,153,51);}
</style>

<div id='wikicmds'>
   <if @back_link@ not nil>
      <a href="@back_link@" accesskey='b' >#xowiki.back#</a> &middot;
   </if>
   <if @item_id@ not nil>
      <a href="@view_link@" accesskey='v' >#xowiki.view#</a> &middot;
      <a href="@rev_link@" accesskey='r' >#xowiki.revisions#</a> &middot;
   </if>
   <a href="index" accesskey='i'>#xowiki.index#</a> 
</div>
  
<formtemplate id="@formTemplate@"></formtemplate>

ad_page_contract {
  a tiny chat client

  @author Gustaf Neumann (gustaf.neumann@wu-wien.ac.at)
  @creation-date Jan 31, 2006
  @cvs-id $Id$
} -query {
  m
  id
  msg:optional
}

::xowiki::Chat c1 -volatile -chat_id $id
switch -- $m {
  add_msg {
    set _ [c1 $m $msg]
    ns_log notice "--c add_msg returns '$_'"
  }
  login -
  get_new -
  get_all {set _ [c1 $m]}
  default {ns_log error "--c unknown method $m called."} 
}

ns_return 200 text/html "
<HTML>
<style type='text/css'>
#messages .timestamp {vertical-align: top; font-size: 80%; color: grey}
#messages .user {text-align: right; vertical-align: top; font-size: 80%; font-weight: bold; color: grey}
#messages .message {vertical-align: top}
</style>
<body>
<table id='messages'><tbody>$_</tbody></table>
</body>
</HTML>"
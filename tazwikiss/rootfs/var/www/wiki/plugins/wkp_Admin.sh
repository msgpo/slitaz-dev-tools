plugin="<a href=\"?action=admin\">Administration</a>"
description_fr="Administration du Wiki"
description="Wiki administration"
      
admin_enable()
{
	[ -n "$(POST $1)" ] || return
	chmod 0 $4$2*
	for i in $(POST); do
		case "$i" in $3*) chmod 755 $4${i/$3/$2}* ;; esac
	done
}

admin_download()
{
	cat - $1 <<EOT
Content-Type: application/octet-stream
Content-Length: $(stat -c %s $1)
Content-Disposition: attachment; filename=${2:-$1}

EOT
}

action()
{
	case "$1" in
	list|config|admin);;
	backup)	file=$(FILE file tmpname)
		if [ -z "$file" ]; then
			file=$(mktemp -p /tmp)
			find */ | cpio -o -H newc | gzip -9 > $file
			admin_download $file wiki-$(date '+%Y%m%d%H%M').cpio.gz
			rm -f $file
			exit 0
		else
			zcat $file | cpio -idmu $(echo */ | sed 's|/||g')
			rm -rf $(dirname $file)
			return 1
		fi ;;
	*)	return 1 ;;
	esac
	PAGE_TITLE_link=false
	editable=false
	lang="${HTTP_ACCEPT_LANGUAGE%%,*}"
	PAGE_TITLE="Administration"
	curpassword="$(POST curpassword)"
	secret="admin.secret"
	if [ -n "$(POST setpassword)" ]; then
		if [ -z "$curpassword" ]; then	# unauthorized
			if [ ! -s $secret -o "$(cat $secret)" == \
				  "$(echo $(POST password) | md5sum)" ]; then
				curpassword="$(POST password)"
			fi
		fi
		[ -n "$curpassword" ] && echo $curpassword | md5sum > $secret
	fi
	if [ -n "$(POST save)" ]; then
		admin_download $(POST file)
		exit 0
	fi
	[ -n "$(POST restore)" ] && mv -f $(FILE data tmpname) $(POST file)
	admin_enable locales config- config_ ./
	admin_enable plugins wkp_ wkp_ plugins/
	disabled="disabled=disabled"
	[ -n "$curpassword" ] && disabled="" && 
	curpassword="<input type=\"hidden\" name=\"curpassword\" value=\"$curpassword\" />
"
	hr="$curpassword<tr><td colspan=2><hr /></td><tr />"
	CONTENT="
<table width=\"100%\">
<form method=\"post\" action=\"?action=admin\">
<tr><td><h2>$MDP</h2></td>
<td><input type=\"text\" name=\"password\" />$curpassword
<input type=\"submit\" value=\"$DONE_BUTTON\" name=\"setpassword\" /></td></tr>
</form>
<form method=\"post\" enctype=\"multipart/form-data\" action=\"?action=admin\">
$hr
<tr><td><h2>Plugins</h2></td>
<td><input type=\"submit\" $disabled value=\"$DONE_BUTTON\" name=\"plugins\" /></td></tr>
"
	for i in $plugins_dir/*.sh ; do
		plugin=
		eval $(grep ^plugin= $i)
		[ -n "$plugin" ] || continue
		eval $(grep ^description= $i)
		alt="$(grep ^description_$lang= $i)"
		[ -n "$alt" ] && eval $(echo "$alt" | sed 's/_..=/=/')
		CONTENT="$CONTENT
<tr><td><b>
<input type=checkbox $disabled $([ -x $i ] && echo 'checked=checked ') name=\"$(basename $i .sh)\" />
$plugin</b></td><td><i>$description</i></td></tr>"
	done
	CONTENT="$CONTENT
</form>
<form method=\"post\" enctype=\"multipart/form-data\" action=\"?action=admin\">
$hr
<tr><td><h2>Locales</h2></td>
<td><input type=\"submit\" $disabled value=\"$DONE_BUTTON\" name=\"locales\" /></td></tr>
"
	for i in config-*.sh ; do
		j=${i#config-}
		j=${j%.sh}
		[ -n "$j" ] && CONTENT="$CONTENT
<tr><td><b>
<input type=checkbox $disabled $([ -x $i ] && echo 'checked=checked ') name=\"config_$j\" />
$j</b></td><td><i>$(. ./$i ; echo $WIKI_TITLE)</i></td></tr>
"
	done
	CONTENT="$CONTENT
</form>
<form method=\"post\" enctype=\"multipart/form-data\" action=\"?action=admin\">
$hr
<tr><td><h2>Configuration</h2></td>
<td><select name="file" $disabled>
$(for i in template.html style.css config*.sh; do
  [ -x $i ] && echo "<option>$i</option>"; done)
</select>
<input type=\"submit\" $disabled value=\"$DONE_BUTTON\" name=\"save\" />
<input type=\"file\" $disabled name=\"data\" />
<input type=\"submit\" $disabled value=\"$RESTORE\" name=\"restore\" /></td></tr>
</form>
<form method=\"post\" enctype=\"multipart/form-data\" action=\"?action=backup\">
$hr
<tr><td><h2>Data</h2></td>
<td><input type=\"submit\" $disabled name=\"save\" value=\"$DONE_BUTTON\" />
<input type=\"file\" $disabled name=\"file\" value=\"file\" />
<input type=\"submit\" $disabled name=\"restore\" value=\"$RESTORE\" />
</td></tr>
$(du -hs */ | sed 's|\(.*\)\t\(.*\)|<tr><td><b>\1</b></td><td><i>\2</i></td></tr>|')
</form>
</table>
"
}

# ------------------------------------------------------------------------------
#  entry.tcl
#  This file is part of Unifix BWidget Toolkit
#  $Id: entry.tcl,v 1.8 2000/02/29 23:04:06 ericm Exp $
# ------------------------------------------------------------------------------
#  Index of commands:
#     - Entry::create
#     - Entry::configure
#     - Entry::cget
#     - Entry::_destroy
#     - Entry::_init_drag_cmd
#     - Entry::_end_drag_cmd
#     - Entry::_drop_cmd
#     - Entry::_over_cmd
#     - Entry::_auto_scroll
#     - Entry::_scroll
# ------------------------------------------------------------------------------

namespace eval Entry {
    Widget::tkinclude Entry entry :cmd \
	    remove [list -state -cursor -foreground -textvariable]
    # Note:  -textvariable is pulled off of the tk entry and put onto the
    # BW Entry so that we avoid the TkResource test for it, which screws up
    # the existance/non-existance bits of the -textvariable.
    Widget::declare Entry [list \
	    [list -foreground		TkResource	""	0 entry] \
	    [list -disabledforeground	TkResource	""	0 button] \
	    [list -state	Enum	normal	0 [list normal disabled]] \
	    [list -text			String	""	0] \
	    [list -textvariable		String	""	0] \
	    [list -editable		Boolean	1	0] \
	    [list -command		String	""	0] \
	    [list -relief		TkResource	""	0 entry] \
	    [list -borderwidth		TkResource	""	0 entry] \
	    [list -fg		Synonym		-foreground] \
	    [list -bd		Synonym		-borderwidth] \
	    ]
    Widget::addmap Entry "" :cmd {-textvariable {}}

    DynamicHelp::include Entry balloon
    DragSite::include    Entry "" 3
    DropSite::include    Entry {
        TEXT    {move {}}
        FGCOLOR {move {}}
        BGCOLOR {move {}}
        COLOR   {move {}}
    }

    foreach event [bind Entry] {
        bind BwEntry $event [bind Entry $event]
    }
    bind BwEntry <Return>  {Entry::invoke %W}
    bind BwEntry <Destroy> {Entry::_destroy %W}
    bind BwDisabledEntry <Destroy> {Entry::_destroy %W}

    proc ::Entry { path args } { return [eval Entry::create $path $args] }
    proc use {} {}
}


# ------------------------------------------------------------------------------
#  Command Entry::create
# ------------------------------------------------------------------------------
proc Entry::create { path args } {
    variable $path
    upvar 0  $path data

    Widget::init Entry $path $args

    set data(afterid) ""
    eval entry $path [Widget::subcget $path :cmd]

    set state    [Widget::cget $path -state]
    set editable [Widget::cget $path -editable]
    if { $editable && ![string compare $state "normal"] } {
        bindtags $path [list $path BwEntry [winfo toplevel $path] all]
        $path configure -takefocus 1
    } else {
        bindtags $path [list $path BwDisabledEntry [winfo toplevel $path] all]
        $path configure -takefocus 0
    }
    if { $editable == 0 } {
        $path configure -cursor left_ptr
    }
    if { ![string compare $state "disabled"] } {
        $path configure -foreground [Widget::cget $path -disabledforeground]
    } else {
	$path configure -foreground [Widget::cget $path -foreground]
    }

    DragSite::setdrag $path $path Entry::_init_drag_cmd Entry::_end_drag_cmd 1
    DropSite::setdrop $path $path Entry::_over_cmd Entry::_drop_cmd 1
    DynamicHelp::sethelp $path $path 1

    rename $path ::$path:cmd
    proc ::$path { cmd args } "return \[Entry::_path_command $path \$cmd \$args\]"

    return $path
}


# ------------------------------------------------------------------------------
#  Command Entry::configure
# ------------------------------------------------------------------------------
proc Entry::configure { path args } {
    variable $path
    upvar 0  $path data

    set res [Widget::configure $path $args]
    set chstate    [Widget::hasChangedX $path -state]
    set cheditable [Widget::hasChangedX $path -editable]
    set chfg       [Widget::hasChangedX $path -foreground]
    set chdfg      [Widget::hasChangedX $path -disabledforeground]

    set state [Widget::cget $path -state]

    if { $chstate || $cheditable } {
	set editable [Widget::cget $path -editable]
        set btags [bindtags $path]
        if { $editable && ![string compare $state "normal"] } {
            set idx [lsearch $btags BwDisabledEntry]
            if { $idx != -1 } {
                bindtags $path [lreplace $btags $idx $idx BwEntry]
            }
            $path:cmd configure -takefocus 1
        } else {
            set idx [lsearch $btags BwEntry]
            if { $idx != -1 } {
                bindtags $path [lreplace $btags $idx $idx BwDisabledEntry]
            }
            $path:cmd configure -takefocus 0
            if { ![string compare [focus] $path] } {
                focus .
            }
        }
    }

    if { $chstate || $chfg || $chdfg } {
        if { ![string compare $state "disabled"] } {
	    set dfg [Widget::cget $path -disabledforeground]
            $path:cmd configure -fg $dfg
        } else {
	    set fg [Widget::cget $path -foreground]
            $path:cmd configure -fg $fg
        }
    }

    if { $cheditable } {
        if { $editable } {
            $path:cmd configure -cursor xterm
        } else {
            $path:cmd configure -cursor left_ptr
        }
    }

    if { [Widget::hasChangedX $path -text] } {
	# Oh my lordee-ba-goordee
	# Do some magic to prevent multiple validation command firings.
	# If there is a textvariable, set that to the right value; if not,
	# disable validation, delete the old text, enable, then set the text.
	set varName [$path:cmd cget -textvariable]
	if { ![string equal $varName ""] } {
	    uplevel \#0 [list set $varName [Widget::cget $path -text]]
	} else {
	    set validateState [$path:cmd cget -validate]
	    $path:cmd configure -validate none
	    $path:cmd delete 0 end
	    $path:cmd configure -validate $validateState
	    $path:cmd insert 0 [Widget::cget $path -text]
	}
    }

    DragSite::setdrag $path $path Entry::_init_drag_cmd Entry::_end_drag_cmd
    DropSite::setdrop $path $path Entry::_over_cmd Entry::_drop_cmd
    DynamicHelp::sethelp $path $path

    return $res
}


# ------------------------------------------------------------------------------
#  Command Entry::cget
# ------------------------------------------------------------------------------
proc Entry::cget { path option } {
    if { [string equal "-text" $option] } {
	return [$path:cmd get]
    }
    return [Widget::cget $path $option]
}


# ------------------------------------------------------------------------------
#  Command Entry::invoke
# ------------------------------------------------------------------------------
proc Entry::invoke { path } {
    if { [set cmd [Widget::getoption $path -command]] != "" } {
        uplevel \#0 $cmd
    }
}


# ------------------------------------------------------------------------------
#  Command Entry::_path_command
# ------------------------------------------------------------------------------
proc Entry::_path_command { path cmd larg } {
    if { ![string compare $cmd "configure"] || ![string compare $cmd "cget"] } {
        return [eval Entry::$cmd $path $larg]
    } else {
        return [eval $path:cmd $cmd $larg]
    }
}


# ------------------------------------------------------------------------------
#  Command Entry::_destroy
# ------------------------------------------------------------------------------
proc Entry::_destroy { path } {
    variable $path
    upvar 0  $path data

    Widget::destroy $path
    rename $path {}
    unset data
}


# ------------------------------------------------------------------------------
#  Command Entry::_init_drag_cmd
# ------------------------------------------------------------------------------
proc Entry::_init_drag_cmd { path X Y top } {
    variable $path
    upvar 0  $path data

    if { [set cmd [Widget::getoption $path -draginitcmd]] != "" } {
        return [uplevel \#0 $cmd [list $path $X $Y $top]]
    }
    set type [Widget::getoption $path -dragtype]
    if { $type == "" } {
        set type "TEXT"
    }
    if { [set drag [$path get]] != "" } {
        if { [$path:cmd selection present] } {
            set idx  [$path:cmd index @[expr $X-[winfo rootx $path]]]
            set sel0 [$path:cmd index sel.first]
            set sel1 [expr [$path:cmd index sel.last]-1]
            if { $idx >=  $sel0 && $idx <= $sel1 } {
                set drag [string range $drag $sel0 $sel1]
                set data(dragstart) $sel0
                set data(dragend)   [expr {$sel1+1}]
                if { ![Widget::getoption $path -editable] ||
                     [Widget::getoption $path -state] == "disabled" } {
                    return [list $type {copy} $drag]
                } else {
                    return [list $type {copy move} $drag]
                }
            }
        } else {
            set data(dragstart) 0
            set data(dragend)   end
            if { ![Widget::getoption $path -editable] ||
                 [Widget::getoption $path -state] == "disabled" } {
                return [list $type {copy} $drag]
            } else {
                return [list $type {copy move} $drag]
            }
        }
    }
}


# ------------------------------------------------------------------------------
#  Command Entry::_end_drag_cmd
# ------------------------------------------------------------------------------
proc Entry::_end_drag_cmd { path target op type dnddata result } {
    variable $path
    upvar 0  $path data

    if { [set cmd [Widget::getoption $path -dragendcmd]] != "" } {
        return [uplevel \#0 $cmd [list $path $target $op $type $dnddata $result]]
    }
    if { $result && $op == "move" && $path != $target } {
        $path:cmd delete $data(dragstart) $data(dragend)
    }
}


# ------------------------------------------------------------------------------
#  Command Entry::_drop_cmd
# ------------------------------------------------------------------------------
proc Entry::_drop_cmd { path source X Y op type dnddata } {
    variable $path
    upvar 0  $path data

    if { $data(afterid) != "" } {
        after cancel $data(afterid)
        set data(afterid) ""
    }
    if { [set cmd [Widget::getoption $path -dropcmd]] != "" } {
        set idx [$path:cmd index @[expr $X-[winfo rootx $path]]]
        return [uplevel \#0 $cmd [list $path $source $idx $op $type $dnddata]]
    }
    if { $type == "COLOR" || $type == "FGCOLOR" } {
        configure $path -foreground $dnddata
    } elseif { $type == "BGCOLOR" } {
        configure $path -background $dnddata
    } else {
        $path:cmd icursor @[expr $X-[winfo rootx $path]]
        if { $op == "move" && $path == $source } {
            $path:cmd delete $data(dragstart) $data(dragend)
        }
        set sel0 [$path index insert]
        $path:cmd insert insert $dnddata
        set sel1 [$path index insert]
        $path:cmd selection range $sel0 $sel1
    }
    return 1
}


# ------------------------------------------------------------------------------
#  Command Entry::_over_cmd
# ------------------------------------------------------------------------------
proc Entry::_over_cmd { path source event X Y op type dnddata } {
    variable $path
    upvar 0  $path data

    set x [expr $X-[winfo rootx $path]]
    if { ![string compare $event "leave"] } {
        if { [string length $data(afterid)] } {
            after cancel $data(afterid)
            set data(afterid) ""
        }
    } elseif { [_auto_scroll $path $x] } {
        return 2
    }

    if { [set cmd [Widget::getoption $path -dropovercmd]] != "" } {
        set x   [expr $X-[winfo rootx $path]]
        set idx [$path:cmd index @$x]
        set res [uplevel \#0 $cmd [list $path $source $event $idx $op $type $dnddata]]
        return $res
    }

    if { ![string compare $type "COLOR"]   ||
         ![string compare $type "FGCOLOR"] ||
         ![string compare $type "BGCOLOR"] } {
        DropSite::setcursor based_arrow_down
        return 1
    }
    if { [Widget::getoption $path -editable] && ![string compare [Widget::getoption $path -state] "normal"] } {
        if { [string compare $event "leave"] } {
            $path:cmd selection clear
            $path:cmd icursor @$x
            DropSite::setcursor based_arrow_down
            return 3
        }
    }
    DropSite::setcursor dot
    return 0
}


# ------------------------------------------------------------------------------
#  Command Entry::_auto_scroll
# ------------------------------------------------------------------------------
proc Entry::_auto_scroll { path x } {
    variable $path
    upvar 0  $path data

    set xmax [winfo width $path]
    if { $x <= 10 && [$path:cmd index @0] > 0 } {
        if { $data(afterid) == "" } {
            set data(afterid) [after 100 "Entry::_scroll $path -1 $x $xmax"]
            DropSite::setcursor sb_left_arrow
        }
        return 1
    } else {
        if { $x >= $xmax-10 && [$path:cmd index @$xmax] < [$path:cmd index end] } {
            if { $data(afterid) == "" } {
                set data(afterid) [after 100 "Entry::_scroll $path 1 $x $xmax"]
                DropSite::setcursor sb_right_arrow
            }
            return 1
        } else {
            if { $data(afterid) != "" } {
                after cancel $data(afterid)
                set data(afterid) ""
            }
        }
    }
    return 0
}


# ------------------------------------------------------------------------------
#  Command Entry::_scroll
# ------------------------------------------------------------------------------
proc Entry::_scroll { path dir x xmax } {
    variable $path
    upvar 0  $path data

    $path:cmd xview scroll $dir units
    $path:cmd icursor @$x
    if { ($dir == -1 && [$path:cmd index @0] > 0) ||
         ($dir == 1  && [$path:cmd index @$xmax] < [$path:cmd index end]) } {
        set data(afterid) [after 100 "Entry::_scroll $path $dir $x $xmax"]
    } else {
        set data(afterid) ""
        DropSite::setcursor dot
    }
}


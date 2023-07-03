#
# HTML Template Engine for Report Generation
#
# @NOTE - This is a proof of concept only.
#   It supports the following embedded macros in HTML:
#    [var NAME] - Insert the value of the kv-pair in Content
#    [include_from FILE] - Recursively expand the referenced file. We
#        only search in the current directory right now. Absolute path
#        should work too.
#    [startloop {args} {obj}] - Start a for loop around a list or dict
#    [emptyloop] - Signifies the start of the content that will render
#        when an empty obj is passed to 'startloop'
#    [endloop] - End the current for loop.
#
# NOTE - I have not tested "Nested" for loops yet so watch out.
#
# To Add in the future:
#    if/else clause
#    extend clause - see here: https://docs.djangoproject.com/en/4.2/ref/templates/builtins/#std-templatetag-extends
#

package require textutil::expander
package require logger 0.3


variable log [logger::init main]
${::log}::setlevel info

# This being global is not what I want but it works and
#   thats what I need right now.
::textutil::expander exp
::exp errmode error

proc LocalApplyTemplate_r {TemplateFile Content Locals} {
    variable C $Content
    # Make a copy of the Locals Dict
    # @NOTE - I was hoping that I could use the context of the
    #   expander to hold these temporary local variables - but
    #   alas, the context gets pushed on entry to `expand` so
    #   there doesn't seem to be an easy way to do that.
    #   This local dict contains the loop variables for a for
    #   loop or any other structure like that.
    variable L [dict replace $Locals]

    # Read the template file.
    # @TODO - This is where we would search through
    #   a list of directories for a matching file.
    ${::log}::debug "Loading Template ${TemplateFile}"
    set fp [ open ${TemplateFile} r]
    set template [read $fp]
    close $fp

    proc var {key} {
	variable C
	variable L
	if { [dict exists $C $key] } {
	    return [dict get $C $key]
	} elseif { [dict exists $L $key] } {
	    return [dict get $L $key]
	} else {

	    ${::log}::debug "UNKNOWN VAR: Locals Content:"
	    dict for {k v} $L {
		${::log}::debug "\t$k $v"
	    }
	    ${::log}::debug "End Locals Content"

	    return "UNKNOWN"
	}
    }

    proc include_from {fname} {
	variable C
	variable L

	# Flush the current text in the context.
	set current [::exp ctopandclear]
	puts $current

	LocalApplyTemplate_r $fname $C $L
    }

    proc evalnorm {macro} {return [uplevel #0 $macro]}
    # Useful for delay'd evaluation of the
    #   macro like in the for loop below.
    proc identity {macro} {
	${::log}::debug "identity: $macro"
	if { $macro != "emptyloop" && $macro != "endloop" } {
	    # Note: that the arguments here have the
	    #    '[' and ']' stripped. I need to add them back in
	    #    but they have to be escaped otherwise it
	    #    evaluates the entire contents as the command -
	    #    which obviously doesn't work if you have any args.
	    return "\[$macro\]"
	} else {
	    # Process the macro normally.
	    return [evalnorm $macro]
	}
    }

    # startloop/emptyloop/endloop
    # The idea here is to provide the ability to loop
    #   over a series of values and expand the content found
    #   between startloop -> endloop or startloop-> emptyloop
    #   for each element.
    #   If emptyloop is present - then we output the content
    #     between emptyloop -> endloop if the passed object
    #     is empty.
    #
    proc startloop {args obj} {
	# Flush the current text
	set current [::exp ctopandclear]
	puts $current

	${::log}::debug "Start For Loop"

	# @TODO - Might need an index for the loop
	#   here to allow for nested loops?
	::exp cpush myLoop

	# Add the object we are interrogating to our
	#   context so we can reference them at the endloop

	::exp cset "_obj" $obj
	::exp cset "_args" $args

	# @TODO check if this is a list or a dict
	#   If it is a list - we expect one arg which will be
	#    the element at each index of the list
	#   If this is a dict - we expect 2 args - the key and
	#    the value

	# We need to set the evalcmd so that we capture the
	#   content and NOT evaluate it.
	#   We want to later expand it for every item in the
	#   iterable.
	::exp evalcmd identity

	# @NOTE - Do this after the 'evalcmd' change -
	#   I'm not sure why - but if it comes before,
	#   then it prints "identity" into the macro text.
	::exp cpush perloop

    }

    proc emptyloop {} {
	${::log}::debug "For Loop - Empty Class Start"

	# @TODO - check that we are in the `per-loop-*`
	#    context. If not then this is template
	#    format error.

	set per_loop [::exp cpop perloop]
	${::log}::debug "Per Loop: $per_loop"

	::exp cset "_per_loop_template" $per_loop

	::exp cpush empty_clause
    }

    # Stackoverflow copy pasta magic
    #   https://stackoverflow.com/questions/29098346/check-if-an-argument-is-a-dictionary-or-not-in-tcl
    proc is_dict {value} {
	return [expr {[string is list $value] && ([llength $value]&1) == 0}]
    }

    proc endloop {} {
	variable L

	# @TODO - check that we are in the `per-loop-*`
	#    context. If not then this is template
	#    format error.

	${::log}::debug "End of For Loop"

	if { [::exp cname] == "empty_clause" } {
	    set empty_clause [::exp cpop empty_clause]
	    set per_loop [::exp cget "_per_loop_template"]
	} else {
	    set per_loop [::exp cpop perloop]
	    set empty_clause ""
	}

	# Reset the evalcmd back to normal so that
	#   when we expand on every iteration of the loop
	#   we evaluate the content
	::exp evalcmd evalnorm

	# Now we implement the for loop and expand the captured
	#  templates at ever step.
	set obj [::exp cget "_obj"]
	set args [::exp cget "_args"]

	if {[string is list $obj]} {
	    if { [is_dict $obj] } {
		if { [dict size $obj] == 0 } { # Empty
		    set content [::exp expand $empty_clause]
		    puts -nonewline $content
		} else {
		    set kvArgs [split $args]
		    set keyName [lindex $kvArgs 0]
		    set valName [lindex $kvArgs 1]

		    foreach {k v} $obj {
			set L [dict set L $keyName $k]
			set L [dict set L $valName $v]

			# Expand Per loop Template Here
			set content [::exp expand $per_loop]
			puts -nonewline $content
		    }
		    dict unset L $keyName
		    dict unset L $valName
		}
	    } else { # List
		if { [llength $obj] == 0 } { # Empty
		    set content [::exp expand $empty_clause]
		    puts -nonewline $content
		} else {
		    foreach item $obj {
			set L [dict set L $args $item]

			set content [::exp expand $per_loop]
			puts -nonewline $content
		    }
		    dict unset L $args
		}
	    }
	}

	::exp cpop myLoop
    }

    set content [::exp expand $template]
    puts $content
}

proc ApplyTemplate {TemplateFile Content} {
    set locDict [dict create]
    return [LocalApplyTemplate_r $TemplateFile $Content $locDict]
}

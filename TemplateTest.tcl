source HTMLTemplate.tcl

ApplyTemplate "./example.thtml" [dict create "name" "VHDL" "answer" "good" "testdict" [dict create "a" 1 "b" 2 "c" 3]]

#  File Name:         VendorScripts_Mentor.tcl
#  Purpose:           Scripts for running simulations
#  Revision:          OSVVM MODELS STANDARD VERSION
# 
#  Maintainer:        Jim Lewis      email:  jim@synthworks.com 
#  Contributor(s):            
#     Jim Lewis      email:  jim@synthworks.com   
# 
#  Description
#    Tcl procedures with the intent of making running 
#    compiling and simulations tool independent
#    
#  Developed by: 
#        SynthWorks Design Inc. 
#        VHDL Training Classes
#        OSVVM Methodology and Model Library
#        11898 SW 128th Ave.  Tigard, Or  97223
#        http://www.SynthWorks.com
# 
#  Revision History:
#    Date      Version    Description
#     5/2022   2022.05    Coverage report name based on TestCaseName rather than LibraryUnit
#                         Updated variable naming 
#     2/2022   2022.02    Added Coverage Collection
#    12/2021   2021.12    Updated to use relative paths.
#     3/2021   2021.03    In Simulate, added optional scripts to run as part of simulate
#     2/2021   2021.02    Refactored variable settings to here from ToolConfiguration.tcl
#     7/2020   2020.07    Refactored tool execution for simpler vendor customization
#     1/2020   2020.01    Updated Licenses to Apache
#     2/2019   Beta       Project descriptors in .pro which execute 
#                         as TCL scripts in conjunction with the library 
#                         procedures
#    11/2018   Alpha      Project descriptors in .files and .dirs files
#
#
#  This file is part of OSVVM.
#  
#  Copyright (c) 2018 - 2022 by SynthWorks Design Inc.    
#  
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#  
#      https://www.apache.org/licenses/LICENSE-2.0
#  
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

# -------------------------------------------------
# Tool Settings
#
  variable ToolType    "simulator"
  variable ToolVendor  "Siemens"
  if {[info exists ::ToolName]} {
    variable ToolName $::ToolName
  } else {
    if {[lindex [split [vsim -version]] 2] eq "ModelSim"} {
      variable ToolName   "ModelSim"
    } else {
      variable ToolName   "QuestaSim"
    }
  }
  variable simulator   $ToolName ; # Deprecated 
  
  if {$argv eq "-c"} {
    variable ToolArgs "-c"
    variable NoGui true
  } elseif {[lindex $argv 1] eq "-batch"} {
    variable ToolArgs "-batch"
    variable NoGui true
  } else {
    variable ToolArgs "-gui"
    variable NoGui false
  }
  variable ToolNameVersion ${ToolName}-[vsimVersion]
  puts $ToolNameVersion


# -------------------------------------------------
# StartTranscript / StopTranscxript
#
proc vendor_StartTranscript {FileName} {
  variable NoGui

  if {$NoGui} {
    DefaultVendor_StartTranscript $FileName
  } else {
    transcript file ""
    echo transcript file $FileName
    transcript file $FileName
  }
}

proc vendor_StopTranscript {FileName} {
  variable NoGui

  # FileName not used here
  transcript file ""
  if {$NoGui} {
    DefaultVendor_StopTranscript $FileName
  } else {
    transcript file ""
  }
}

# -------------------------------------------------
# IsVendorCommand
#
proc IsVendorCommand {LineOfText} {

  return [regexp {^vlib |^vmap |^vcom |^vlog |^vsim |^run |^coverage |^vcover } $LineOfText] 
}

# -------------------------------------------------
# SetCoverageAnalyzeOptions
# SetCoverageCoverageOptions
#
proc vendor_SetCoverageAnalyzeDefaults {} {
  variable CoverageAnalyzeOptions
#  set CoverageAnalyzeOptions "+cover=bcesft"
  set CoverageAnalyzeOptions "+cover=bsf"
}

proc vendor_SetCoverageSimulateDefaults {} {
  variable CoverageSimulateOptions
  set CoverageSimulateOptions "-coverage"
}

# -------------------------------------------------
# Library
#
proc vendor_library {LibraryName PathToLib} {
  set PathAndLib ${PathToLib}/${LibraryName}

  if {![file exists ${PathAndLib}]} {
    puts "vlib   ${PathAndLib} "
          vlib   ${PathAndLib}
  }
  puts "vmap   $LibraryName  ${PathAndLib}"
        vmap   $LibraryName  ${PathAndLib}
}

proc vendor_LinkLibrary {LibraryName PathToLib} {
  set PathAndLib ${PathToLib}/${LibraryName}

  if {[file exists ${PathAndLib}]} {
    set ResolvedLib ${PathAndLib}
  } else {
    set ResolvedLib ${PathToLib}
  }
  echo vmap    $LibraryName  ${ResolvedLib}
       vmap    $LibraryName  ${ResolvedLib}
}

# -------------------------------------------------
# analyze
#
proc vendor_analyze_vhdl {LibraryName FileName OptionalCommands} {
  variable VhdlVersion
#  puts "vcom -${VhdlVersion} -work ${LibraryName} {*}${OptionalCommands} ${FileName} "
        vcom -${VhdlVersion} -work ${LibraryName} {*}${OptionalCommands} ${FileName}
}

proc vendor_analyze_verilog {LibraryName FileName OptionalCommands} {
  set  AnalyzeOptions [concat [CreateVerilogLibraryParams "-l "] -work ${LibraryName} {*}${OptionalCommands} ${FileName}]
  puts "vlog $AnalyzeOptions"
        vlog {*}$AnalyzeOptions
}

# -------------------------------------------------
# End Previous Simulation
#
proc vendor_end_previous_simulation {} {
  global SourceMap
  variable NoGui

  # close junk in source window
  if {! $NoGui} {
    if {![catch {noview} msg]} {
      foreach index [array names SourceMap] { 
        noview source [file tail $index] 
      }
    }
  }  
  
  quit -sim
}

# -------------------------------------------------
# vendor_simulate
#
# Note about ignored vsim warnings:
# During simulation OSVVM suppresses QuestaSim/ModelSim messages 8683 and 8684.
# These are warnings about potential issues with port drivers due to QuestaSim/ModelSim 
# using non-VHDL compliant optimizations.  The potential issues these warn about 
# do not occur with OSVVM interfaces.   As a result, these warnings are suppressed 
# because they consume significant time at the startup of simulations. 
#  
# You can learn more about these messages by doing “verror 8683” or “verror 8684” 
# from within the tool GUI.   
# 
# verror 8683
# ------------------------------------------ 
# 
# An output port has no default expression in its declaration and has no drivers.  
# The VHDL LRM-compliant value it propagates to higher-level connected signals may 
# not be what is desired.  In particular, this behavior might not correspond to 
# the synthesis view of initialization.  The vsim switch "-defaultstdlogicinittoz" 
# or "-forcestdlogicinittoz"may be useful in this situation.
# 
# OSVVM Analysis of Message # 8683
# ------------------------------------------ 
# 
# OSVVM interfaces that is used to connect VC to the test sequencer (TestCtrl) use 
# minimum as a resolution function.  Driving the default value (type'left) on a 
# signal has no negative impact.  Hence, OSVVM disables this warning since it does 
# not apply.
# 
# verror 8684
# ------------------------------------------ 
# 
# An output port having no drivers has been combined with a higher-level connected 
# signal.  The port will get its initial value from this higher-level connected 
# signal; this is not compliant with the behavior required by the VHDL LRM.  
# 
# LRM compliant behavior would require the port's initial value come from its 
# declaration, however, since it was combined or collapsed with the port or signal 
# higher in the hierarchy, the initial value came from that port or signal.
# 
# LRM compliant behavior can be obtained by preventing the collapsing of these ports 
# with the vsim switch -donotcollapsepartiallydriven. If the port is collapsed to a 
# port or signal with the same initialization (as is often the case of default 
# initializations being applied), there is no problem and the proper initialization 
# is done and the simulation is LRM compliant.
# 
# OSVVM Analysis of Message # 8684
# ------------------------------------------ 
# 
# Older OSVVM VC use records whose elements are std_logic_vector.   These VC 
# initialize port values to 'Z'.  QuestaSim non-VHDL compliant optimizations, such as 
# port collapsing, remove these values.  If you are using older OSVVM verification 
# components, you can avoid any impact of this non compliant behavior if you initialize 
# the transaction interface signal in the test harness to all 'Z'.  
#  
# Hence, OSVVM disables this warning since it does not apply if you use the due 
# care recommended above.
# 
# OSVVM recommends that you migrate older interfaces to the newer that uses types 
# and resolution functions defined in ResolutionPkg such as std_logic_max, 
# std_logic_vector_max, or std_logic_vector_max_c rather than std_logic or 
# std_logic_vector.   ResolutionPkg supports a richer set of types, such as 
# integer_max, real_max, ...
#
proc vendor_simulate {LibraryName LibraryUnit OptionalCommands} {
  variable SCRIPT_DIR
  variable SimulateTimeUnits
  variable CoverageSimulateEnable
  variable TestSuiteName
  variable TestCaseFileName
  
  if {$::osvvm::NoGui} {
    set VsimOptions ""
  } else {
    set VsimOptions "-voptargs=+acc"
  }

  set VsimOptions "$VsimOptions -t $SimulateTimeUnits -lib ${LibraryName} ${LibraryUnit} ${OptionalCommands} -suppress 8683 -suppress 8684"
  
#  puts "vsim {*}${VsimOptions}"
  vsim {*}${VsimOptions}

  # Historical name.  Must be run with "do" for actions to work
  if {[file exists ${SCRIPT_DIR}/Siemens.do]} {
    do ${SCRIPT_DIR}/Siemens.do
  }
  
  SimulateRunScripts ${LibraryUnit}
  
  # Removed.  Desirable, but causes crashes if no signals in testbench.
#  add log -r [env]/*
#  run 1 ns 
  run -all 
  
  if {[info exists CoverageSimulateEnable]} {
    coverage save ${::osvvm::CoverageDirectory}/${TestSuiteName}/${TestCaseFileName}.ucdb 
  }
}

# -------------------------------------------------
proc vendor_generic {Name Value} {
  
  return "-g${Name}=${Value}"
}


# -------------------------------------------------
# Merge Coverage
#
proc vendor_MergeCodeCoverage {TestSuiteName CoverageDirectory BuildName} { 
  set CoverageFileBaseName [file join ${CoverageDirectory} ${BuildName} ${TestSuiteName}]
  vcover merge ${CoverageFileBaseName}.ucdb {*}[glob ${CoverageDirectory}/${TestSuiteName}/*.ucdb]
}

proc vendor_ReportCodeCoverage {TestSuiteName CodeCoverageDirectory} { 
  set CodeCovResultsDir ${CodeCoverageDirectory}/${TestSuiteName}_code_cov
  if {[file exists $CodeCovResultsDir]} {
    file delete -force -- $CodeCovResultsDir
  }
  vcover report -html -annotate -details -verbose -output ${CodeCovResultsDir} ${CodeCoverageDirectory}/${TestSuiteName}.ucdb 
}

proc vendor_GetCoverageFileName {TestName} { 
  set CoverageFileName ${TestName}_code_cov/index.html
  return $CoverageFileName
}

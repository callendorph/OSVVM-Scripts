source "HTMLTemplate.tcl"

set content [dict create "ReportBuildName" "Test Report" "BuildStatus" "FAILED" "TestCasesPassed" 10 "TestCasesFailed" 2 "TestCasesSkipped" 0 "ReportAnalyzeErrorCount" 0 "ReportSimulateErrorCount" 0 "ElapsedTimeHms" "00:02:03" "ElapsedTimeSeconds" 123]

ApplyTemplate "./header_report.thtml" $content
